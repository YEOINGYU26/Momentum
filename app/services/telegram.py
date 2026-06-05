import logging

import httpx

from app.core.config import Settings

logger = logging.getLogger(__name__)


class TelegramNotifier:
    def __init__(self, settings: Settings):
        self._token = settings.telegram_bot_token
        self._chat_id = settings.telegram_chat_id
        self._enabled = bool(self._token and self._chat_id)

    async def send(self, message: str) -> None:
        if not self._enabled:
            logger.debug("텔레그램 미설정, 메시지 스킵: %s", message)
            return
        url = f"https://api.telegram.org/bot{self._token}/sendMessage"
        payload = {"chat_id": self._chat_id, "text": message, "parse_mode": "HTML"}
        try:
            async with httpx.AsyncClient() as client:
                await client.post(url, json=payload, timeout=5)
        except Exception as e:
            logger.warning("텔레그램 발송 실패: %s", e)

    async def notify_order(self, side: str, ticker: str, price: int, quantity: int) -> None:
        emoji = "🔴 매도" if side == "sell" else "🟢 매수"
        await self.send(
            f"{emoji} 주문 체결\n"
            f"종목: <b>{ticker}</b>\n"
            f"가격: {price:,}원\n"
            f"수량: {quantity}주"
        )

    async def notify_alert(self, message: str) -> None:
        await self.send(f"⚠️ {message}")

    async def notify_error(self, error: str) -> None:
        await self.send(f"❌ 오류 발생\n{error}")
