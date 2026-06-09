"""
APScheduler 기반 전략 자동 실행 서비스

- AsyncIOScheduler: FastAPI와 동일한 이벤트 루프 사용
- 잡 ID: {ticker}_{strategy_name} (조합당 1개)
- 실행 이력: 잡당 최근 50건 인메모리 보관
"""

import logging
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

import pandas as pd
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from app.kis.market import MarketAPI
from app.kis.orders import OrdersAPI
from app.services.push import PushNotifier
from app.strategies.base import Signal
from app.strategies.moving_average import MovingAverageStrategy
from app.strategies.rsi import RSIStrategy
from app.strategies.scalping import ScalpingStrategy

logger = logging.getLogger(__name__)

_STRATEGIES = {
    "rsi": RSIStrategy(),
    "moving_average": MovingAverageStrategy(),
    "scalping": ScalpingStrategy(),
}

_HISTORY_SIZE = 50


@dataclass
class JobConfig:
    ticker: str
    strategy_name: str
    interval_seconds: int       # 0이면 cron 사용
    quantity: int
    cron: Optional[str] = None  # ex) "*/5 9-15 * * 1-5"


@dataclass
class ExecutionRecord:
    job_id: str
    executed_at: str            # ISO8601
    signal: str
    reason: str
    confidence: float
    order_result: Optional[dict] = None
    error: Optional[str] = None


class StrategyScheduler:
    def __init__(
        self,
        market_api: MarketAPI,
        orders_api: OrdersAPI,
        notifier: PushNotifier,
    ):
        self._market = market_api
        self._orders = orders_api
        self._notifier = notifier
        self._scheduler = AsyncIOScheduler(timezone="Asia/Seoul")
        self._configs: dict[str, JobConfig] = {}
        self._history: dict[str, deque[ExecutionRecord]] = {}

    # ------------------------------------------------------------------ #
    # 라이프사이클
    # ------------------------------------------------------------------ #

    def start(self) -> None:
        self._scheduler.start()
        logger.info("[Scheduler] 시작")

    def shutdown(self) -> None:
        self._scheduler.shutdown(wait=False)
        logger.info("[Scheduler] 종료")

    # ------------------------------------------------------------------ #
    # 잡 관리
    # ------------------------------------------------------------------ #

    def add_job(self, config: JobConfig) -> str:
        if config.strategy_name not in _STRATEGIES:
            raise ValueError(f"알 수 없는 전략: {config.strategy_name}. 사용 가능: {list(_STRATEGIES)}")

        job_id = f"{config.ticker}_{config.strategy_name}"

        if config.cron:
            trigger = CronTrigger.from_crontab(config.cron, timezone="Asia/Seoul")
        elif config.interval_seconds > 0:
            trigger = IntervalTrigger(seconds=config.interval_seconds)
        else:
            raise ValueError("interval_seconds > 0 이거나 cron 표현식이 있어야 합니다")

        # 기존 잡 교체
        if self._scheduler.get_job(job_id):
            self._scheduler.remove_job(job_id)

        self._scheduler.add_job(
            self._execute,
            trigger=trigger,
            id=job_id,
            kwargs={"job_id": job_id, "config": config},
            max_instances=1,
            misfire_grace_time=30,
            replace_existing=True,
        )
        self._configs[job_id] = config
        if job_id not in self._history:
            self._history[job_id] = deque(maxlen=_HISTORY_SIZE)

        logger.info(
            "[Scheduler] 잡 등록: %s — %s초마다 (cron=%s)",
            job_id, config.interval_seconds, config.cron,
        )
        return job_id

    def remove_job(self, job_id: str) -> None:
        if not self._scheduler.get_job(job_id):
            raise KeyError(f"잡 없음: {job_id}")
        self._scheduler.remove_job(job_id)
        self._configs.pop(job_id, None)
        logger.info("[Scheduler] 잡 제거: %s", job_id)

    def pause_job(self, job_id: str) -> None:
        self._scheduler.pause_job(job_id)

    def resume_job(self, job_id: str) -> None:
        self._scheduler.resume_job(job_id)

    async def run_now(self, job_id: str) -> ExecutionRecord:
        config = self._configs.get(job_id)
        if not config:
            raise KeyError(f"잡 없음: {job_id}")
        return await self._execute(job_id=job_id, config=config)

    def list_jobs(self) -> list[dict]:
        result = []
        for job in self._scheduler.get_jobs():
            cfg = self._configs.get(job.id)
            history = list(self._history.get(job.id, []))
            result.append({
                "job_id": job.id,
                "ticker": cfg.ticker if cfg else "",
                "strategy": cfg.strategy_name if cfg else "",
                "interval_seconds": cfg.interval_seconds if cfg else 0,
                "cron": cfg.cron if cfg else None,
                "quantity": cfg.quantity if cfg else 0,
                "next_run": job.next_run_time.isoformat() if job.next_run_time else None,
                "status": "paused" if job.next_run_time is None else "running",
                "last_execution": history[-1].__dict__ if history else None,
            })
        return result

    def get_history(self, job_id: str) -> list[ExecutionRecord]:
        return list(self._history.get(job_id, []))

    # ------------------------------------------------------------------ #
    # 실행 로직
    # ------------------------------------------------------------------ #

    async def _execute(self, job_id: str, config: JobConfig) -> ExecutionRecord:
        executed_at = datetime.now().isoformat()
        logger.info("[Scheduler] 실행: %s", job_id)

        try:
            record = await self._run_strategy(job_id, config, executed_at)
        except Exception as e:
            logger.error("[Scheduler] 실행 오류 %s: %s", job_id, e)
            await self._notifier.notify_error(f"[{job_id}] {e}")
            record = ExecutionRecord(
                job_id=job_id,
                executed_at=executed_at,
                signal="error",
                reason=str(e),
                confidence=0.0,
                error=str(e),
            )

        if job_id in self._history:
            self._history[job_id].append(record)
        return record

    async def _run_strategy(
        self, job_id: str, config: JobConfig, executed_at: str
    ) -> ExecutionRecord:
        # 1. OHLCV 데이터 수집
        rows = await self._market.get_daily_ohlcv(config.ticker, period="D")
        if not rows:
            raise RuntimeError("OHLCV 데이터 없음")

        df = pd.DataFrame(rows)
        for col in ("open", "high", "low", "close", "volume"):
            df[col] = df[col].astype(float)
        df = df.sort_values("date").reset_index(drop=True)

        # 2. 전략 분석
        strategy = _STRATEGIES[config.strategy_name]
        result = strategy.analyze(df)
        current_price = int(df["close"].iloc[-1])

        logger.info(
            "[Scheduler] %s → %s (%s, confidence=%.2f)",
            job_id, result.signal.value, result.reason, result.confidence,
        )

        # 3. 신호에 따른 주문
        order_result: Optional[dict] = None
        if result.signal == Signal.BUY:
            order_result = await self._orders.buy_market(config.ticker, config.quantity)
            await self._notifier.notify_order("buy", config.ticker, current_price, config.quantity)
            await self._notifier.send(
                title=f"📊 [{config.strategy_name.upper()}] {config.ticker}",
                body=f"매수 신호 | {result.reason}",
                data={"type": "strategy", "ticker": config.ticker, "signal": "buy"},
            )
        elif result.signal == Signal.SELL:
            order_result = await self._orders.sell_market(config.ticker, config.quantity)
            await self._notifier.notify_order("sell", config.ticker, current_price, config.quantity)
            await self._notifier.send(
                title=f"📊 [{config.strategy_name.upper()}] {config.ticker}",
                body=f"매도 신호 | {result.reason}",
                data={"type": "strategy", "ticker": config.ticker, "signal": "sell"},
            )

        return ExecutionRecord(
            job_id=job_id,
            executed_at=executed_at,
            signal=result.signal.value,
            reason=result.reason,
            confidence=result.confidence,
            order_result=order_result,
        )
