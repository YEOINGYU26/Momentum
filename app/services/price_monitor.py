import asyncio
import logging
from dataclasses import dataclass, field
from typing import Optional

from app.kis.market import MarketAPI
from app.kis.orders import OrdersAPI
from app.services.push import PushNotifier

logger = logging.getLogger(__name__)


@dataclass
class PriceAlert:
    ticker: str
    target_price: int
    side: str          # "buy" | "sell"
    quantity: int
    active: bool = True
    triggered: bool = False


@dataclass
class MonitorState:
    alerts: list[PriceAlert] = field(default_factory=list)
    _task: Optional[asyncio.Task] = field(default=None, repr=False)


class PriceMonitorService:
    """지정가 도달 감시 — 백그라운드 폴링"""

    def __init__(
        self,
        market_api: MarketAPI,
        orders_api: OrdersAPI,
        notifier: PushNotifier,
        interval: float = 5.0,
    ):
        self._market = market_api
        self._orders = orders_api
        self._notifier = notifier
        self._interval = interval
        self._state = MonitorState()

    def add_alert(self, alert: PriceAlert) -> None:
        self._state.alerts.append(alert)
        logger.info("알림 등록: %s %s @ %s", alert.side, alert.ticker, alert.target_price)

    def remove_alert(self, ticker: str) -> int:
        before = len(self._state.alerts)
        self._state.alerts = [a for a in self._state.alerts if a.ticker != ticker]
        return before - len(self._state.alerts)

    def list_alerts(self) -> list[PriceAlert]:
        return list(self._state.alerts)

    async def _check_once(self) -> None:
        active = [a for a in self._state.alerts if a.active and not a.triggered]
        if not active:
            return

        tickers = list({a.ticker for a in active})
        prices: dict[str, int] = {}
        for ticker in tickers:
            try:
                data = await self._market.get_price(ticker)
                prices[ticker] = data["current_price"]
            except Exception as e:
                logger.warning("시세 조회 실패 %s: %s", ticker, e)

        for alert in active:
            price = prices.get(alert.ticker)
            if price is None:
                continue
            triggered = (
                (alert.side == "buy" and price <= alert.target_price)
                or (alert.side == "sell" and price >= alert.target_price)
            )
            if not triggered:
                continue

            alert.triggered = True
            logger.info("지정가 도달 — %s %s %d주 @ %d", alert.side, alert.ticker, alert.quantity, price)
            try:
                if alert.side == "buy":
                    result = await self._orders.buy_limit(alert.ticker, alert.quantity, alert.target_price)
                else:
                    result = await self._orders.sell_limit(alert.ticker, alert.quantity, alert.target_price)
                await self._notifier.notify_order(alert.side, alert.ticker, price, alert.quantity)
                logger.info("주문 완료: %s", result)
            except Exception as e:
                alert.triggered = False
                logger.error("주문 실패: %s", e)
                await self._notifier.notify_error(str(e))

    async def _loop(self) -> None:
        logger.info("가격 모니터링 시작 (간격: %ss)", self._interval)
        while True:
            try:
                await self._check_once()
            except Exception as e:
                logger.error("모니터링 오류: %s", e)
            await asyncio.sleep(self._interval)

    def start(self) -> None:
        if self._state._task and not self._state._task.done():
            return
        self._state._task = asyncio.create_task(self._loop())

    def stop(self) -> None:
        if self._state._task:
            self._state._task.cancel()
