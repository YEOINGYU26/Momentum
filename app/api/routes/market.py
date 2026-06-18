from fastapi import APIRouter, Depends

from app.core.dependencies import get_market_api
from app.data.symbols import search_symbols
from app.kis import master as stock_master
from app.kis.market import MarketAPI

router = APIRouter(prefix="/market", tags=["market"])

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

    # 해외주식 + 암호화폐: symbols.py 사용
    others = [
        {
            "ticker":   s.ticker,
            "name":     s.name,
            "sub":      s.sub,
            "exchange": s.exchange,
            "category": s.category,
        }
        for s in search_symbols(q, category)
        if s.category != "주식"
    ]

    if category == "주식":
        return korean
    if category in ("해외주식", "암호화폐"):
        return others
    return korean + others


@router.get("/price/{ticker}")
async def get_price(ticker: str, api: MarketAPI = Depends(get_market_api)):
    return await api.get_price(ticker)


@router.get("/ohlcv/{ticker}")
async def get_ohlcv(
    ticker: str,
    interval: str = "1d",
    api: MarketAPI = Depends(get_market_api),
):
    try:
        if interval == "all":
            return await api.get_daily_ohlcv_all(ticker, "D")   # max 100콜
        if interval == "1y":
            return await api.get_yearly_ohlcv(ticker)
        if interval in _PERIOD_MAP:
            period, pages = _PERIOD_MAP[interval]
            return await api.get_daily_ohlcv_all(ticker, period, max_pages=pages)
        minutes, calls = _MINUTE_MAP.get(interval, (1, 1))
        return await api.get_minute_ohlcv(ticker, interval_minutes=minutes, calls=calls)
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"OHLCV 실패 {ticker} interval={interval}: {e}")
        return []
