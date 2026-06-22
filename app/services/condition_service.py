"""
복합 조건 자동매매 서비스

여러 조건(AND)이 모두 충족될 때 주문 실행:
  - line_trigger: 현재가가 추세선/매매선에 접촉
  - rsi: RSI가 기준값 이하(매수) / 이상(매도)
  - moving_average: 골든크로스/데드크로스 감지
  - scalping: 볼린저밴드 하단/상단 이탈
"""

import asyncio
import logging
import time
import uuid
from dataclasses import dataclass, field
from typing import Optional

import pandas as pd

from app.data.symbols import is_us_ticker
from app.kis import us_master
from app.kis.market import MarketAPI
from app.kis.orders import OrdersAPI
from app.services.push import PushNotifier
from app.strategies.base import Signal
from app.strategies.moving_average import MovingAverageStrategy
from app.strategies.rsi import RSIStrategy
from app.strategies.scalping import ScalpingStrategy

logger = logging.getLogger(__name__)

_STRATEGIES = {
    "moving_average": MovingAverageStrategy(),
    "scalping": ScalpingStrategy(),
}


def _tick_unit(price: float) -> int:
    p = int(price)
    if p < 2_000:     return 1
    if p < 5_000:     return 5
    if p < 20_000:    return 10
    if p < 50_000:    return 50
    if p < 200_000:   return 100
    if p < 500_000:   return 500
    return 1_000


# ── 데이터 모델 ───────────────────────────────────────────────────────────────

@dataclass
class LineCondition:
    start_time: int
    start_price: float
    end_time: int
    end_price: float

    def effective_price(self, ts: int) -> float:
        if self.end_time == self.start_time:
            return self.start_price
        frac = (ts - self.start_time) / (self.end_time - self.start_time)
        return self.start_price + frac * (self.end_price - self.start_price)


@dataclass
class IndicatorCondition:
    type: str                         # 'rsi' | 'moving_average' | 'scalping'
    rsi_buy_thr: float = 30.0
    rsi_sell_thr: float = 70.0


@dataclass
class CompoundRule:
    ticker: str
    side: str                         # 'buy' | 'sell'
    quantity: int
    interval_seconds: int
    timeframe: str                    # 'D' | 'W' | 'M' | 'Y'
    line_conditions: list[LineCondition] = field(default_factory=list)
    indicator_conditions: list[IndicatorCondition] = field(default_factory=list)
    rule_id: str = field(default_factory=lambda: str(uuid.uuid4())[:8])
    created_at: float = field(default_factory=time.time)
    triggered_count: int = 0

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "ticker": self.ticker,
            "side": self.side,
            "quantity": self.quantity,
            "interval_seconds": self.interval_seconds,
            "timeframe": self.timeframe,
            "line_conditions": [
                {"start_time": lc.start_time, "start_price": lc.start_price,
                 "end_time": lc.end_time, "end_price": lc.end_price}
                for lc in self.line_conditions
            ],
            "indicator_conditions": [
                {"type": ic.type, "rsi_buy_thr": ic.rsi_buy_thr, "rsi_sell_thr": ic.rsi_sell_thr}
                for ic in self.indicator_conditions
            ],
            "created_at": self.created_at,
            "triggered_count": self.triggered_count,
        }


# ── 서비스 ────────────────────────────────────────────────────────────────────

class ConditionService:
    def __init__(self, market_api: MarketAPI, orders_api: OrdersAPI, notifier: PushNotifier):
        self._market = market_api
        self._orders = orders_api
        self._notifier = notifier
        self._rules: dict[str, CompoundRule] = {}
        self._tasks: dict[str, asyncio.Task] = {}

    # ── 라이프사이클 ──────────────────────────────────────────────────────────

    def stop(self) -> None:
        for task in self._tasks.values():
            task.cancel()
        self._tasks.clear()

    # ── CRUD ─────────────────────────────────────────────────────────────────

    def add_rule(self, rule: CompoundRule) -> None:
        self._rules[rule.rule_id] = rule
        task = asyncio.create_task(self._loop(rule.rule_id))
        self._tasks[rule.rule_id] = task
        logger.info("[Condition] 규칙 등록: %s (%s %s, 조건 %d개)",
                    rule.rule_id, rule.ticker, rule.side,
                    len(rule.line_conditions) + len(rule.indicator_conditions))

    def remove_rule(self, rule_id: str) -> bool:
        if rule_id not in self._rules:
            return False
        del self._rules[rule_id]
        if task := self._tasks.pop(rule_id, None):
            task.cancel()
        logger.info("[Condition] 규칙 삭제: %s", rule_id)
        return True

    def list_rules(self) -> list[dict]:
        return [r.to_dict() for r in self._rules.values()]

    # ── 백그라운드 루프 ───────────────────────────────────────────────────────

    async def _loop(self, rule_id: str) -> None:
        while rule_id in self._rules:
            rule = self._rules.get(rule_id)
            if rule is None:
                break
            try:
                await self._evaluate(rule)
            except Exception as e:
                logger.error("[Condition] 평가 오류 (%s): %s", rule_id, e)
            await asyncio.sleep(rule.interval_seconds)

    async def _evaluate(self, rule: CompoundRule) -> None:
        # 현재가 조회
        try:
            if is_us_ticker(rule.ticker):
                exch = us_master.lookup_exchange(rule.ticker)
                price_data = await self._market.get_us_price(rule.ticker, exch)
            else:
                price_data = await self._market.get_price(rule.ticker)
            current_price: float = price_data["current_price"]
        except Exception as e:
            logger.warning("[Condition] 가격 조회 실패 (%s): %s", rule.ticker, e)
            return

        results: list[bool] = []

        # 1) 매매선 터치 조건
        if rule.line_conditions:
            now = int(time.time())
            any_hit = False
            for lc in rule.line_conditions:
                target = lc.effective_price(now)
                tick = _tick_unit(target) if not is_us_ticker(rule.ticker) else 0.01
                if abs(current_price - target) <= tick * 3:
                    any_hit = True
                    break
            results.append(any_hit)

        # 2) 지표 조건
        ohlcv_df: Optional[pd.DataFrame] = None
        for ic in rule.indicator_conditions:
            signal = await self._run_indicator(ic, rule.ticker, rule.timeframe, ohlcv_df)
            target_signal = Signal.BUY if rule.side == "buy" else Signal.SELL
            results.append(signal == target_signal)

        # 전체 AND 충족 시 주문
        if results and all(results):
            logger.info("[Condition] 조건 충족 (%s): %s %s", rule.rule_id, rule.ticker, rule.side)
            await self._execute(rule, current_price)

    async def _run_indicator(
        self,
        ic: IndicatorCondition,
        ticker: str,
        timeframe: str,
        cached_df: Optional[pd.DataFrame],
    ) -> Signal:
        try:
            rows = await self._market.get_daily_ohlcv(ticker, period=timeframe)
            if not rows:
                return Signal.HOLD
            df = pd.DataFrame(rows)
            for col in ("open", "high", "low", "close", "volume"):
                if col in df.columns:
                    df[col] = df[col].astype(float)
            df = df.sort_values("date").reset_index(drop=True)

            if ic.type == "rsi":
                strategy = RSIStrategy(oversold=ic.rsi_buy_thr, overbought=ic.rsi_sell_thr)
            elif ic.type in _STRATEGIES:
                strategy = _STRATEGIES[ic.type]
            else:
                return Signal.HOLD

            return strategy.analyze(df).signal
        except Exception as e:
            logger.warning("[Condition] 지표 실행 실패 (%s %s): %s", ic.type, ticker, e)
            return Signal.HOLD

    async def _execute(self, rule: CompoundRule, current_price: float) -> None:
        try:
            if is_us_ticker(rule.ticker):
                exch = us_master.lookup_exchange(rule.ticker)
                if rule.side == "buy":
                    await self._orders.buy_us_market(rule.ticker, rule.quantity, exch)
                else:
                    await self._orders.sell_us_market(rule.ticker, rule.quantity, exch)
            else:
                tick = _tick_unit(current_price)
                price_int = round(current_price / tick) * tick
                if rule.side == "buy":
                    await self._orders.buy_limit(rule.ticker, rule.quantity, price_int)
                else:
                    await self._orders.sell_limit(rule.ticker, rule.quantity, price_int)

            rule.triggered_count += 1
            side_label = "매수" if rule.side == "buy" else "매도"
            await self._notifier.send(
                title=f"조건 {side_label} 실행",
                body=f"{rule.ticker} {rule.quantity}주 — 복합 조건 충족 ({rule.triggered_count}회)",
            )
        except Exception as e:
            logger.error("[Condition] 주문 실패 (%s): %s", rule.rule_id, e)
