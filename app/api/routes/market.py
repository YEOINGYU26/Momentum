from fastapi import APIRouter, Depends

from app.core.dependencies import get_market_api
from app.kis.market import MarketAPI

router = APIRouter(prefix="/market", tags=["market"])


@router.get("/price/{ticker}")
async def get_price(ticker: str, api: MarketAPI = Depends(get_market_api)):
    return await api.get_price(ticker)


@router.get("/ohlcv/{ticker}")
async def get_ohlcv(
    ticker: str,
    period: str = "D",
    api: MarketAPI = Depends(get_market_api),
):
    return await api.get_daily_ohlcv(ticker, period)
