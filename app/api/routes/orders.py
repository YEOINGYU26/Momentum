from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from app.core.dependencies import get_orders_api, get_price_monitor
from app.data.symbols import is_us_ticker
from app.kis import us_master
from app.kis.orders import OrdersAPI
from app.services.price_monitor import PriceAlert, PriceMonitorService

router = APIRouter(prefix="/orders", tags=["orders"])


class OrderRequest(BaseModel):
    ticker: str = Field(..., examples=["005930"])
    quantity: int = Field(..., gt=0)
    price: float = Field(..., gt=0)   # KRW(원) 또는 USD (소수점 지원)


class MarketOrderRequest(BaseModel):
    ticker: str = Field(..., examples=["005930"])
    quantity: int = Field(..., gt=0)


class AlertRequest(BaseModel):
    ticker: str = Field(..., examples=["005930"])
    target_price: float = Field(default=0.0, ge=0)   # KRW 또는 USD
    side: str = Field(..., pattern="^(buy|sell)$")
    quantity: int = Field(..., gt=0)
    # 추세선 알람 (선택)
    line_start_time: Optional[int] = None
    line_start_price: Optional[float] = None
    line_end_time: Optional[int] = None
    line_end_price: Optional[float] = None


@router.post("/buy/limit")
async def buy_limit(req: OrderRequest, api: OrdersAPI = Depends(get_orders_api)):
    if is_us_ticker(req.ticker):
        exchange = us_master.lookup_exchange(req.ticker)
        return await api.buy_us_limit(req.ticker, req.quantity, req.price, exchange)
    return await api.buy_limit(req.ticker, req.quantity, int(req.price))


@router.post("/sell/limit")
async def sell_limit(req: OrderRequest, api: OrdersAPI = Depends(get_orders_api)):
    if is_us_ticker(req.ticker):
        exchange = us_master.lookup_exchange(req.ticker)
        return await api.sell_us_limit(req.ticker, req.quantity, req.price, exchange)
    return await api.sell_limit(req.ticker, req.quantity, int(req.price))


@router.post("/buy/market")
async def buy_market(req: MarketOrderRequest, api: OrdersAPI = Depends(get_orders_api)):
    if is_us_ticker(req.ticker):
        exchange = us_master.lookup_exchange(req.ticker)
        return await api.buy_us_market(req.ticker, req.quantity, exchange)
    return await api.buy_market(req.ticker, req.quantity)


@router.post("/sell/market")
async def sell_market(req: MarketOrderRequest, api: OrdersAPI = Depends(get_orders_api)):
    if is_us_ticker(req.ticker):
        exchange = us_master.lookup_exchange(req.ticker)
        return await api.sell_us_market(req.ticker, req.quantity, exchange)
    return await api.sell_market(req.ticker, req.quantity)


@router.post("/alerts")
async def create_alert(
    req: AlertRequest,
    monitor: PriceMonitorService = Depends(get_price_monitor),
):
    is_trendline = req.line_start_time is not None
    if not is_trendline and req.target_price <= 0:
        raise HTTPException(status_code=400, detail="고정가 알람은 target_price > 0 이어야 합니다")
    alert = PriceAlert(
        ticker=req.ticker,
        target_price=req.target_price,
        side=req.side,
        quantity=req.quantity,
        line_start_time=req.line_start_time,
        line_start_price=req.line_start_price,
        line_end_time=req.line_end_time,
        line_end_price=req.line_end_price,
    )
    monitor.add_alert(alert)
    return {"status": "registered", "alert": req.model_dump()}


@router.get("/alerts")
async def list_alerts(monitor: PriceMonitorService = Depends(get_price_monitor)):
    return [
        {
            "ticker": a.ticker,
            "target_price": a.target_price,
            "side": a.side,
            "quantity": a.quantity,
            "triggered": a.triggered,
            "is_trendline": a.is_trendline,
            "line_start_time":  a.line_start_time,
            "line_start_price": a.line_start_price,
            "line_end_time":    a.line_end_time,
            "line_end_price":   a.line_end_price,
        }
        for a in monitor.list_alerts()
    ]


@router.delete("/alerts/{ticker}")
async def delete_alerts(
    ticker: str,
    monitor: PriceMonitorService = Depends(get_price_monitor),
):
    removed = monitor.remove_alert(ticker)
    if removed == 0:
        raise HTTPException(status_code=404, detail="해당 종목 알림 없음")
    return {"removed": removed}
