import pandas as pd
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.dependencies import get_market_api
from app.kis.market import MarketAPI
from app.strategies.rsi import RSIStrategy
from app.strategies.moving_average import MovingAverageStrategy
from app.strategies.scalping import ScalpingStrategy

router = APIRouter(prefix="/strategy", tags=["strategy"])

_STRATEGIES = {
    "rsi": RSIStrategy(),
    "moving_average": MovingAverageStrategy(),
    "scalping": ScalpingStrategy(),
}


@router.get("/analyze/{strategy_name}/{ticker}")
async def analyze(
    strategy_name: str,
    ticker: str,
    api: MarketAPI = Depends(get_market_api),
):
    strategy = _STRATEGIES.get(strategy_name)
    if strategy is None:
        raise HTTPException(status_code=404, detail=f"전략 없음: {strategy_name}. 사용가능: {list(_STRATEGIES)}")

    rows = await api.get_daily_ohlcv(ticker, period="D")
    if not rows:
        raise HTTPException(status_code=502, detail="OHLCV 데이터 없음")

    df = pd.DataFrame(rows)
    df["close"] = df["close"].astype(float)
    df["high"] = df["high"].astype(float)
    df["low"] = df["low"].astype(float)
    df["open"] = df["open"].astype(float)
    df["volume"] = df["volume"].astype(float)
    df = df.sort_values("date").reset_index(drop=True)

    result = strategy.analyze(df)
    return {
        "ticker": ticker,
        "strategy": strategy_name,
        "signal": result.signal.value,
        "reason": result.reason,
        "confidence": result.confidence,
        "suggested_price": result.suggested_price,
    }


@router.get("/strategies")
async def list_strategies():
    return list(_STRATEGIES.keys())
