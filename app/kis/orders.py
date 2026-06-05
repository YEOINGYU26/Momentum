from app.kis.client import KISClient
from app.core.config import Settings


# 모의투자 tr_id
_TR_BUY_MOCK = "VTTC0802U"
_TR_SELL_MOCK = "VTTC0801U"
# 실거래 tr_id
_TR_BUY_REAL = "TTTC0802U"
_TR_SELL_REAL = "TTTC0801U"


class OrdersAPI:
    """주문 관련 KIS API"""

    def __init__(self, client: KISClient, settings: Settings):
        self._client = client
        self._settings = settings

    def _tr_id(self, side: str) -> str:
        if self._settings.kis_is_mock:
            return _TR_BUY_MOCK if side == "buy" else _TR_SELL_MOCK
        return _TR_BUY_REAL if side == "buy" else _TR_SELL_REAL

    async def _place_order(
        self,
        side: str,
        ticker: str,
        quantity: int,
        price: int,
        order_type: str = "00",
    ) -> dict:
        """
        order_type:
          "00" - 지정가
          "01" - 시장가
        """
        payload = {
            "CANO": self._settings.kis_account_no,
            "ACNT_PRDT_CD": self._settings.kis_account_product_code,
            "PDNO": ticker,
            "ORD_DVSN": order_type,
            "ORD_QTY": str(quantity),
            "ORD_UNPR": str(price) if order_type == "00" else "0",
        }
        body = await self._client.post(
            "/uapi/domestic-stock/v1/trading/order-cash",
            self._tr_id(side),
            payload,
        )
        output = body.get("output", {})
        return {
            "order_no": output.get("ODNO", ""),
            "order_time": output.get("ORD_TMD", ""),
            "ticker": ticker,
            "side": side,
            "quantity": quantity,
            "price": price,
            "order_type": order_type,
        }

    async def buy_limit(self, ticker: str, quantity: int, price: int) -> dict:
        return await self._place_order("buy", ticker, quantity, price, "00")

    async def sell_limit(self, ticker: str, quantity: int, price: int) -> dict:
        return await self._place_order("sell", ticker, quantity, price, "00")

    async def buy_market(self, ticker: str, quantity: int) -> dict:
        return await self._place_order("buy", ticker, quantity, 0, "01")

    async def sell_market(self, ticker: str, quantity: int) -> dict:
        return await self._place_order("sell", ticker, quantity, 0, "01")
