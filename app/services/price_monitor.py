import asyncio
import logging
from dataclasses import dataclass, field
from typing import Optional

from app.kis.market import MarketAPI
from app.kis.market_hours import market_status, is_us_market_open
from app.kis.orders import OrdersAPI
from app.data.symbols import is_us_ticker
from app.kis import us_master
from app.services.push import PushNotifier

logger = logging.getLogger(__name__)


def _tick_unit(price: int) -> int:
    """KIS 국내주식 호가 단위 (코스피/코스닥 공통)"""
    if price < 2_000:       return 1
    if price < 5_000:       return 5
    if price < 20_000:      return 10
    if price < 50_000:      return 50
    if price < 200_000:     return 100
    if price < 500_000:     return 500
    return 1_000


@dataclass
class PriceAlert:
    ticker: str
    target_price: float     # 고정가 알람용 — KRW(int형 float) 또는 USD(소수점). 추세선은 0 전달.
    side: str               # "buy" | "sell"
    quantity: int
    active: bool = True
    triggered: bool = False
    # 추세선 알람 — 모두 None 이면 고정가 알람
    line_start_time: Optional[int] = None
    line_start_price: Optional[float] = None
    line_end_time: Optional[int] = None
    line_end_price: Optional[float] = None

    @property
    def is_trendline(self) -> bool:
        return self.line_start_time is not None

    def effective_target(self, now_ts: int) -> float:
        """현재 시각의 유효 목표가 반환 (추세선이면 선형 보간/외삽)"""
        if not self.is_trendline:
            return float(self.target_price)
        t0, p0 = self.line_start_time, self.line_start_price
        t1, p1 = self.line_end_time,   self.line_end_price
        if t1 == t0:
            return float(p0)
        frac = (now_ts - t0) / (t1 - t0)
        return p0 + frac * (p1 - p0)


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
        kr_status = market_status()
        us_open   = is_us_market_open()

        all_active = [a for a in self._state.alerts if a.active and not a.triggered]
        if not all_active:
            return

        # 현재 거래 가능한 알림만 필터
        active = [
            a for a in all_active
            if (is_us_ticker(a.ticker) and us_open)
            or (not is_us_ticker(a.ticker) and kr_status in ("open", "pre_market", "after_hours"))
        ]
        if not active:
            return

        tickers = list({a.ticker for a in active})
        prices: dict[str, float] = {}
        for ticker in tickers:
            try:
                data = await self._market.get_price(ticker)
                prices[ticker] = float(data["current_price"])
            except Exception as e:
                logger.warning("시세 조회 실패 %s: %s", ticker, e)

        import time as _time
        now_ts = int(_time.time())

        for alert in active:
            price = prices.get(alert.ticker)
            if price is None:
                continue
            target = alert.effective_target(now_ts)
            hit = (
                (alert.side == "buy"  and price <= target)
                or (alert.side == "sell" and price >= target)
            )
            if not hit:
                continue

            alert.triggered = True
            kind = "추세선" if alert.is_trendline else "지정가"

            if is_us_ticker(alert.ticker):
                # 해외주식 — USD, 소수점 2자리 반올림
                order_price_f = round(target, 2)
                exchange = us_master.lookup_exchange(alert.ticker)
                logger.info("%s 도달 [US] — %s %s %d주 @ %.2f (목표 %.2f → 주문가 %.2f)",
                            kind, alert.side, alert.ticker, alert.quantity,
                            price, target, order_price_f)
                try:
                    if alert.side == "buy":
                        result = await self._orders.buy_us_limit(
                            alert.ticker, alert.quantity, order_price_f, exchange
                        )
                    else:
                        result = await self._orders.sell_us_limit(
                            alert.ticker, alert.quantity, order_price_f, exchange
                        )
                    await self._notifier.notify_order(
                        alert.side, alert.ticker, price, alert.quantity
                    )
                    logger.info("주문 완료: %s", result)
                except Exception as e:
                    alert.triggered = False
                    logger.error("주문 실패: %s", e)
                    await self._notifier.notify_error(str(e))
            else:
                # 국내주식 — KRW, KIS 호가 단위 반올림
                tick = _tick_unit(int(target))
                order_price_i = round(target / tick) * tick
                logger.info("%s 도달 [%s] — %s %s %d주 @ %d (목표 %.0f → 주문가 %d)",
                            kind, kr_status, alert.side, alert.ticker, alert.quantity,
                            price, target, order_price_i)
                try:
                    if kr_status == "pre_market":
                        order_fn = self._orders.buy_pre_market if alert.side == "buy" \
                            else self._orders.sell_pre_market
                    elif kr_status == "after_hours":
                        order_fn = self._orders.buy_after_hours if alert.side == "buy" \
                            else self._orders.sell_after_hours
                    else:
                        order_fn = self._orders.buy_limit if alert.side == "buy" \
                            else self._orders.sell_limit
                    result = await order_fn(alert.ticker, alert.quantity, order_price_i)
                    await self._notifier.notify_order(
                        alert.side, alert.ticker, price, alert.quantity
                    )
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
