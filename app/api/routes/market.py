from fastapi import APIRouter, Depends

from app.core.dependencies import get_market_api
from app.kis.market import MarketAPI

router = APIRouter(prefix="/market", tags=["market"])

_PERIOD_MAP = {"1d": "D", "1w": "W", "1mo": "M"}

# interval → (집계 분, API 호출 횟수)
_MINUTE_MAP = {
    "1m":  (1,  1),
    "5m":  (5,  3),   # 90분 → 18개 5분봉
    "15m": (15, 5),   # 150분 → 10개 15분봉
    "1h":  (60, 5),   # 150분 → 2~3개 1시간봉
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
            return await api.get_daily_ohlcv_all(ticker, "D")
        if interval == "1y":
            return await api.get_yearly_ohlcv(ticker)
        if interval in _PERIOD_MAP:
            return await api.get_daily_ohlcv(ticker, _PERIOD_MAP[interval])
        minutes, calls = _MINUTE_MAP.get(interval, (1, 1))
        return await api.get_minute_ohlcv(ticker, interval_minutes=minutes, calls=calls)
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"OHLCV 실패 {ticker} interval={interval}: {e}")
        return []
