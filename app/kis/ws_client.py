"""
KIS 실시간 WebSocket 클라이언트

흐름:
  1. POST /oauth2/Approval → approval_key 발급 (REST 토큰과 별도)
  2. ws://ops.koreainvestment.com:21000 연결
  3. 종목 구독 요청 전송 (tr_id: H0STCNT0)
  4. 수신 메시지 파싱 후 on_price 콜백 호출
  5. 연결 끊기면 지수 백오프로 재접속
"""

import asyncio
import json
import logging
from dataclasses import dataclass
from typing import Awaitable, Callable, Optional

import httpx
import websockets
from websockets.exceptions import ConnectionClosed

from app.core.config import Settings

logger = logging.getLogger(__name__)

# 실시간 체결가 tr_id (모의/실거래 공통)
_TR_REALTIME_PRICE = "H0STCNT0"


@dataclass
class PriceUpdate:
    ticker: str
    time: str          # HHMMSS
    price: int
    change: int        # 전일대비
    change_rate: float # 전일대비율
    open: int
    high: int
    low: int
    ask: int           # 매도호가1
    bid: int           # 매수호가1
    volume: int        # 체결거래량
    cumulative_volume: int


OnPriceCallback = Callable[[PriceUpdate], Awaitable[None]]


def _parse_price_message(raw: str) -> Optional[PriceUpdate]:
    """
    KIS 실시간 메시지 파싱
    형식: encrypt_flag|tr_id|data_cnt|data (^구분)
    """
    parts = raw.split("|")
    if len(parts) < 4:
        return None
    tr_id = parts[1]
    if tr_id != _TR_REALTIME_PRICE:
        return None

    fields = parts[3].split("^")
    if len(fields) < 14:
        return None

    try:
        return PriceUpdate(
            ticker=fields[0],
            time=fields[1],
            price=int(fields[2]),
            change=int(fields[4]),
            change_rate=float(fields[5]),
            open=int(fields[7]),
            high=int(fields[8]),
            low=int(fields[9]),
            ask=int(fields[10]),
            bid=int(fields[11]),
            volume=int(fields[12]),
            cumulative_volume=int(fields[13]),
        )
    except (ValueError, IndexError) as e:
        logger.debug("메시지 파싱 실패: %s — %s", e, raw[:80])
        return None


class KISWebSocketClient:
    def __init__(self, settings: Settings, on_price: OnPriceCallback):
        self._settings = settings
        self._on_price = on_price
        self._approval_key: str = ""
        self._subscriptions: set[str] = set()
        self._ws: Optional[websockets.WebSocketClientProtocol] = None
        self._task: Optional[asyncio.Task] = None
        self._stop_event = asyncio.Event()

    # ------------------------------------------------------------------ #
    # 공개 인터페이스
    # ------------------------------------------------------------------ #

    async def subscribe(self, ticker: str) -> None:
        self._subscriptions.add(ticker)
        if self._ws and not self._ws.closed:
            await self._send_subscribe(ticker)
        logger.info("[WS] 구독 등록: %s", ticker)

    async def unsubscribe(self, ticker: str) -> None:
        self._subscriptions.discard(ticker)
        if self._ws and not self._ws.closed:
            await self._send_unsubscribe(ticker)
        logger.info("[WS] 구독 해제: %s", ticker)

    def subscribed_tickers(self) -> list[str]:
        return sorted(self._subscriptions)

    def start(self) -> None:
        if self._task and not self._task.done():
            return
        self._stop_event.clear()
        self._task = asyncio.create_task(self._connect_loop())

    def stop(self) -> None:
        self._stop_event.set()
        if self._task:
            self._task.cancel()

    # ------------------------------------------------------------------ #
    # 내부 구현
    # ------------------------------------------------------------------ #

    async def _get_approval_key(self) -> str:
        url = f"{self._settings.kis_base_url}/oauth2/Approval"
        payload = {
            "grant_type": "client_credentials",
            "appkey": self._settings.kis_app_key,
            "secretkey": self._settings.kis_app_secret,
        }
        async with httpx.AsyncClient(verify=False) as client:
            resp = await client.post(url, json=payload, timeout=10)
            resp.raise_for_status()
        return resp.json()["approval_key"]

    def _subscribe_msg(self, ticker: str, tr_type: str) -> str:
        return json.dumps({
            "header": {
                "approval_key": self._approval_key,
                "custtype": "P",
                "tr_type": tr_type,   # "1"=구독, "2"=해제
                "content-type": "utf-8",
            },
            "body": {
                "input": {
                    "tr_id": _TR_REALTIME_PRICE,
                    "tr_key": ticker,
                }
            },
        })

    async def _send_subscribe(self, ticker: str) -> None:
        await self._ws.send(self._subscribe_msg(ticker, "1"))

    async def _send_unsubscribe(self, ticker: str) -> None:
        await self._ws.send(self._subscribe_msg(ticker, "2"))

    async def _handle_message(self, raw: str) -> None:
        # PINGPONG 처리 (JSON 형태로 수신)
        if raw.startswith("{"):
            try:
                body = json.loads(raw)
                if body.get("header", {}).get("tr_id") == "PINGPONG":
                    await self._ws.send(raw)  # pong
            except json.JSONDecodeError:
                pass
            return

        update = _parse_price_message(raw)
        if update:
            await self._on_price(update)

    async def _connect_and_run(self) -> None:
        self._approval_key = await self._get_approval_key()
        logger.info("[WS] approval_key 발급 완료, %s 연결 시도", self._settings.kis_ws_url)

        async with websockets.connect(
            self._settings.kis_ws_url,
            ping_interval=20,
            ping_timeout=10,
        ) as ws:
            self._ws = ws
            logger.info("[WS] 연결 성공")

            # 기존 구독 목록 재등록 (재접속 시)
            for ticker in list(self._subscriptions):
                await self._send_subscribe(ticker)

            async for message in ws:
                if self._stop_event.is_set():
                    break
                await self._handle_message(message)

    async def _connect_loop(self) -> None:
        backoff = 1.0
        while not self._stop_event.is_set():
            try:
                await self._connect_and_run()
            except asyncio.CancelledError:
                break
            except ConnectionClosed as e:
                logger.warning("[WS] 연결 종료: %s", e)
            except Exception as e:
                logger.error("[WS] 오류: %s", e)

            if self._stop_event.is_set():
                break

            logger.info("[WS] %.0fs 후 재접속 시도", backoff)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60.0)

        self._ws = None
        logger.info("[WS] 루프 종료")
