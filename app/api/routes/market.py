import time
from dataclasses import dataclass
from typing import Optional

from fastapi import APIRouter, Depends

from app.core.dependencies import get_market_api
from app.data.symbols import search_symbols, is_us_ticker
from app.kis import master as stock_master
from app.kis import us_master
from app.kis.market import MarketAPI

router = APIRouter(prefix="/market", tags=["market"])

# ── OHLCV 인메모리 TTL 캐시 ─────────────────────────────────────────────────
@dataclass
class _CacheEntry:
    data: list
    expires_at: float

_ohlcv_cache: dict[str, _CacheEntry] = {}

# 일봉/주봉/월봉/전체/연봉: 10분 캐시 (장중에도 일봉은 하루 1번 확정)
# 분봉: 30초 캐시 (실시간성 유지)
_CACHE_TTL: dict[str, int] = {
    "1d": 600, "1w": 600, "1mo": 600, "all": 600, "1y": 600,
    "1m": 30, "5m": 30, "15m": 30, "1h": 60,
}

def _cache_get(ticker: str, interval: str) -> Optional[list]:
    entry = _ohlcv_cache.get(f"{ticker}_{interval}")
    if entry and time.time() < entry.expires_at:
        return entry.data
    return None

def _cache_set(ticker: str, interval: str, data: list) -> None:
    ttl = _CACHE_TTL.get(interval, 600)
    _ohlcv_cache[f"{ticker}_{interval}"] = _CacheEntry(data=data, expires_at=time.time() + ttl)

# interval → (period, max_pages)
# max_pages=0 → get_daily_ohlcv 1회 호출 (분봉 aggregation용)
_PERIOD_MAP = {
    "1d":  ("D", 15),   # 15콜×100개 ≈ 6년 일봉
    "1w":  ("W", 30),   # 30콜×100개 ≈ 전체 주봉 (100주=약 2년/콜)
    "1mo": ("M", 10),   # 10콜×100개 ≈ 전체 월봉 (100개월=약 8년/콜)
}

# interval → (집계 분, API 호출 횟수)
# KIS 1분봉 API: 호출당 30개 레코드, 1 영업일 ≈ 13콜
# KIS 1분봉 API는 콜당 30개 고정 → 과도한 콜은 타임아웃 원인
# 1m: 15콜(450분≈1.2영업일), 5m: 25콜(750분→150개), 15m: 40콜(1200분→80개), 1h: 50콜(1500분→25개)
_MINUTE_MAP = {
    "1m":  (1,  15),
    "5m":  (5,  25),
    "15m": (15, 40),
    "1h":  (60, 50),
}


@router.get("/search")
async def search(q: str = "", category: str = "전체"):
    # 국내주식: 마스터 캐시 우선 (2,500개+), 미로드 시 symbols.py 폴백
    if category in ("전체", "주식") and stock_master.is_loaded():
        master_results = stock_master.search(q, limit=100)
        korean = [
            {
                "ticker":   s.ticker,
                "name":     s.name,
                "sub":      s.name,
                "exchange": s.exchange,
                "category": "주식",
            }
            for s in master_results
        ]
    else:
        korean = [
            {
                "ticker":   s.ticker,
                "name":     s.name,
                "sub":      s.sub,
                "exchange": s.exchange,
                "category": s.category,
            }
            for s in search_symbols(q, "주식")
            if category in ("전체", "주식")
        ]

    # 해외주식: 마스터 캐시 우선(수만 종목), 미로드 시 symbols.py 폴백
    us_results: list[dict] = []
    if category in ("전체", "해외주식"):
        if us_master.is_loaded():
            us_results = [
                {
                    "ticker":   it.ticker,
                    "name":     it.name,
                    "sub":      it.name,
                    "exchange": it.exchange,
                    "category": "해외주식",
                }
                for it in us_master.search(q, limit=50)
            ]
        else:
            us_results = [
                {
                    "ticker":   s.ticker,
                    "name":     s.name,
                    "sub":      s.sub,
                    "exchange": s.exchange,
                    "category": s.category,
                }
                for s in search_symbols(q, "해외주식")
            ]

    # 암호화폐: symbols.py 사용
    crypto_results: list[dict] = []
    if category in ("전체", "암호화폐"):
        crypto_results = [
            {
                "ticker":   s.ticker,
                "name":     s.name,
                "sub":      s.sub,
                "exchange": s.exchange,
                "category": s.category,
            }
            for s in search_symbols(q, "암호화폐")
        ]

    if category == "주식":
        return korean
    if category == "해외주식":
        return us_results
    if category == "암호화폐":
        return crypto_results
    return korean + us_results + crypto_results


@router.get("/price/{ticker}")
async def get_price(ticker: str, api: MarketAPI = Depends(get_market_api)):
    return await api.get_price(ticker)


_US_GUBN_MAP = {"D": "0", "W": "1", "M": "2"}


@router.get("/ohlcv/{ticker}")
async def get_ohlcv(
    ticker: str,
    interval: str = "1d",
    api: MarketAPI = Depends(get_market_api),
):
    if cached := _cache_get(ticker, interval):
        return cached

    try:
        if is_us_ticker(ticker):
            # ── 해외주식 OHLCV ──────────────────────────────────────────
            exchange = us_master.lookup_exchange(ticker)
            if interval == "all":
                result = await api.get_us_ohlcv_all(ticker, exchange, "0", max_pages=100)
            elif interval == "1y":
                monthly = await api.get_us_ohlcv_all(ticker, exchange, "2", max_pages=10)
                result = _aggregate_yearly_us(monthly)
            elif interval in _PERIOD_MAP:
                period, pages = _PERIOD_MAP[interval]
                gubn = _US_GUBN_MAP.get(period, "0")
                result = await api.get_us_ohlcv_all(ticker, exchange, gubn, max_pages=pages)
            else:
                # 분봉 미지원 — 일봉 5페이지로 대체
                result = await api.get_us_ohlcv_all(ticker, exchange, "0", max_pages=5)
        else:
            # ── 국내주식 OHLCV ──────────────────────────────────────────
            if interval == "all":
                result = await api.get_daily_ohlcv_all(ticker, "D")
            elif interval == "1y":
                result = await api.get_yearly_ohlcv(ticker)
            elif interval in _PERIOD_MAP:
                period, pages = _PERIOD_MAP[interval]
                result = await api.get_daily_ohlcv_all(ticker, period, max_pages=pages)
            else:
                minutes, calls = _MINUTE_MAP.get(interval, (1, 1))
                result = await api.get_minute_ohlcv(ticker, interval_minutes=minutes, calls=calls)
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"OHLCV 실패 {ticker} interval={interval}: {e}")
        return []

    if result:
        _cache_set(ticker, interval, result)
    return result


def _aggregate_yearly_us(monthly: list[dict]) -> list[dict]:
    yearly: dict[str, dict] = {}
    for r in monthly:
        year = r["date"][:4]
        if year not in yearly:
            yearly[year] = {
                "date": year + "0101",
                "open": r["open"], "high": r["high"],
                "low":  r["low"],  "close": r["close"],
                "volume": r["volume"],
            }
        else:
            yearly[year]["high"]   = max(yearly[year]["high"], r["high"])
            yearly[year]["low"]    = min(yearly[year]["low"],  r["low"])
            yearly[year]["close"]  = r["close"]
            yearly[year]["volume"] += r["volume"]
    return sorted(yearly.values(), key=lambda r: r["date"])
