import asyncio
import logging
from typing import Optional

from app.core.config import Settings

logger = logging.getLogger(__name__)


class PushNotifier:
    """FCM 네이티브 푸시 알림 서비스"""

    def __init__(self, settings: Settings):
        self._credentials_path = settings.fcm_credentials_path
        self._enabled = bool(self._credentials_path)
        self._tokens: set[str] = set()

        if self._enabled:
            try:
                import firebase_admin
                from firebase_admin import credentials
                if not firebase_admin._apps:
                    cred = credentials.Certificate(self._credentials_path)
                    firebase_admin.initialize_app(cred)
                logger.info("FCM 초기화 완료")
            except Exception as e:
                logger.error("FCM 초기화 실패: %s", e)
                self._enabled = False

    def register_token(self, token: str) -> None:
        self._tokens.add(token)
        logger.info("FCM 토큰 등록 (총 %d개)", len(self._tokens))

    def unregister_token(self, token: str) -> None:
        self._tokens.discard(token)
        logger.info("FCM 토큰 해제 (총 %d개)", len(self._tokens))

    def list_tokens(self) -> list[str]:
        return list(self._tokens)

    async def send(self, title: str, body: str, data: Optional[dict] = None) -> None:
        if not self._enabled or not self._tokens:
            logger.debug("FCM 미설정 또는 등록된 기기 없음, 알림 스킵")
            return
        try:
            from firebase_admin import messaging
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                tokens=list(self._tokens),
            )
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None, messaging.send_each_for_multicast, message
            )
            if response.failure_count > 0:
                tokens_snapshot = list(self._tokens)
                for i, resp in enumerate(response.responses):
                    if not resp.success and i < len(tokens_snapshot):
                        logger.warning("FCM 토큰 만료, 제거: %s…", tokens_snapshot[i][:20])
                        self._tokens.discard(tokens_snapshot[i])
            logger.info("FCM 발송: 성공 %d / 실패 %d", response.success_count, response.failure_count)
        except Exception as e:
            logger.warning("FCM 발송 실패: %s", e)

    async def notify_order(self, side: str, ticker: str, price: int, quantity: int) -> None:
        emoji = "🔴" if side == "sell" else "🟢"
        action = "매도" if side == "sell" else "매수"
        await self.send(
            title=f"{emoji} {action} 주문 체결",
            body=f"{ticker}  {price:,}원 × {quantity}주",
            data={"type": "order", "ticker": ticker, "side": side},
        )

    async def notify_alert(self, message: str) -> None:
        await self.send(title="⚠️ 지정가 알림", body=message, data={"type": "alert"})

    async def notify_error(self, error: str) -> None:
        await self.send(title="❌ 오류 발생", body=error, data={"type": "error"})
