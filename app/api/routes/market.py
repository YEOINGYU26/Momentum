from fastapi import APIRouter, Depends

from app.core.dependencies import get_market_api
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
_MINUTE_MAP = {
    "1m":  (1,  1),
    "5m":  (5,  3),
    "15m": (15, 5),
    "1h":  (60, 10),
}


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
