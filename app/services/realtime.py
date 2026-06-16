"""
실시간 시세 브로드캐스트 서비스

KISWebSocketClient에서 받은 PriceUpdate를
해당 ticker를 구독 중인 FastAPI WebSocket 클라이언트 전체에 broadcast.
"""

import asyncio
import json
import logging
from collections import defaultdict
from dataclasses import asdict
from typing import Optional

from fastapi import WebSocket

from app.core.config import Settings
from app.kis.ws_client import KISWebSocketClient, PriceUpdate

logger = logging.getLogger(__name__)


class RealtimeService:
    def __init__(self, settings: Settings):
        self._settings = settings
        # ticker → FastAPI WebSocket 연결 집합
        self._clients: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()
        self._kis_ws: Optional[KISWebSocketClient] = None

    # ------------------------------------------------------------------ #
    # 라이프사이클
    # ------------------------------------------------------------------ #

    def start(self) -> None:
        # KISWebSocketClient 인스턴스만 생성. connect_loop는 첫 구독자가 생길 때 시작.
        self._kis_ws = KISWebSocketClient(
            settings=self._settings,
            on_price=self._broadcast,
        )
        logger.info("[Realtime] 서비스 준비 완료 (WS는 첫 구독자 연결 시 시작)")

    def stop(self) -> None:
        if self._kis_ws:
            self._kis_ws.stop()
        logger.info("[Realtime] 서비스 종료")

    # ------------------------------------------------------------------ #
    # 클라이언트(FastAPI WS) 연결 관리
    # ------------------------------------------------------------------ #

    async def connect(self, ticker: str, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._clients[ticker].add(ws)
            if len(self._clients[ticker]) == 1 and self._kis_ws:
                # 첫 구독자 → connect_loop가 꺼져 있으면 켠다
                if self._kis_ws._task is None or self._kis_ws._task.done():
                    self._kis_ws.start()
                await self._kis_ws.subscribe(ticker)
        logger.info("[Realtime] 클라이언트 연결: %s (총 %d)", ticker, len(self._clients[ticker]))

    async def disconnect(self, ticker: str, ws: WebSocket) -> None:
        async with self._lock:
            self._clients[ticker].discard(ws)
            if not self._clients[ticker] and self._kis_ws:
                await self._kis_ws.unsubscribe(ticker)
                del self._clients[ticker]
                # 모든 구독자가 사라지면 connect_loop도 정지
                if not self._kis_ws.subscribed_tickers():
                    self._kis_ws.stop()
                    logger.info("[Realtime] 구독자 없음 — KIS WS 정지")
        logger.info("[Realtime] 클라이언트 해제: %s", ticker)

    # ------------------------------------------------------------------ #
    # 브로드캐스트
    # ------------------------------------------------------------------ #

    async def _broadcast(self, update: PriceUpdate) -> None:
        ticker = update.ticker
        payload = json.dumps(asdict(update), ensure_ascii=False)

        async with self._lock:
            clients = set(self._clients.get(ticker, set()))

        if not clients:
            return

        dead: list[WebSocket] = []
        for ws in clients:
            try:
                await ws.send_text(payload)
            except Exception:
                dead.append(ws)

        # 끊긴 연결 정리
        if dead:
            async with self._lock:
                for ws in dead:
                    self._clients[ticker].discard(ws)

    # ------------------------------------------------------------------ #
    # 상태 조회
    # ------------------------------------------------------------------ #

    def status(self) -> dict:
        connected = self._kis_ws is not None and (
            self._kis_ws._ws is not None and not self._kis_ws._ws.closed
        )
        return {
            "connected": connected,
            "subscribed_tickers": self._kis_ws.subscribed_tickers() if self._kis_ws else [],
            "client_counts": {
                ticker: len(clients)
                for ticker, clients in self._clients.items()
            },
        }
