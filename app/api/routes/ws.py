import logging

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from app.core.dependencies import get_realtime_service
from app.services.realtime import RealtimeService

router = APIRouter(tags=["realtime"])
logger = logging.getLogger(__name__)


@router.websocket("/ws/price/{ticker}")
async def ws_price(
    ticker: str,
    ws: WebSocket,
    service: RealtimeService = Depends(get_realtime_service),
):
    """
    실시간 체결가 WebSocket

    연결: ws://localhost:8000/ws/price/005930

    수신 메시지 (JSON):
    {
        "ticker": "005930",
        "time": "094512",
        "price": 72000,
        "change": 500,
        "change_rate": 0.7,
        "open": 71500,
        "high": 72300,
        "low": 71200,
        "ask": 72100,
        "bid": 71900,
        "volume": 1234,
        "cumulative_volume": 5678900
    }
    """
    await service.connect(ticker, ws)
    try:
        while True:
            # 클라이언트 ping/메시지 수신 대기 (연결 유지 목적)
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await service.disconnect(ticker, ws)


@router.get("/api/v1/realtime/status")
async def realtime_status(service: RealtimeService = Depends(get_realtime_service)):
    """WebSocket 연결 상태 및 구독 종목 조회"""
    return service.status()
