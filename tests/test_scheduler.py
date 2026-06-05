import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime

from app.services.scheduler import StrategyScheduler, JobConfig, ExecutionRecord
from app.strategies.base import Signal, StrategyResult


def _make_scheduler(signal: Signal = Signal.HOLD, ohlcv_rows=None):
    market_api = AsyncMock()
    orders_api = AsyncMock()
    notifier = AsyncMock()

    if ohlcv_rows is None:
        # 충분한 OHLCV 데이터 (RSI period=14 이상)
        ohlcv_rows = [
            {"date": str(i), "open": 100, "high": 105, "low": 95, "close": 100, "volume": 1000}
            for i in range(30)
        ]

    market_api.get_daily_ohlcv.return_value = ohlcv_rows

    # 전략 모킹
    mock_strategy = MagicMock()
    mock_strategy.analyze.return_value = StrategyResult(signal=signal, reason="테스트 신호", confidence=0.9)

    sched = StrategyScheduler(market_api, orders_api, notifier)
    return sched, market_api, orders_api, notifier, mock_strategy


class TestJobManagement:
    def test_add_job_returns_job_id(self):
        sched, *_ = _make_scheduler()
        sched._scheduler.start()
        try:
            job_id = sched.add_job(JobConfig(
                ticker="005930",
                strategy_name="rsi",
                interval_seconds=300,
                quantity=1,
            ))
            assert job_id == "005930_rsi"
            assert sched._scheduler.get_job("005930_rsi") is not None
        finally:
            sched.shutdown()

    def test_add_job_unknown_strategy_raises(self):
        sched, *_ = _make_scheduler()
        sched._scheduler.start()
        try:
            with pytest.raises(ValueError, match="알 수 없는 전략"):
                sched.add_job(JobConfig(
                    ticker="005930",
                    strategy_name="nonexistent",
                    interval_seconds=60,
                    quantity=1,
                ))
        finally:
            sched.shutdown()

    def test_add_job_no_interval_or_cron_raises(self):
        sched, *_ = _make_scheduler()
        sched._scheduler.start()
        try:
            with pytest.raises(ValueError):
                sched.add_job(JobConfig(
                    ticker="005930",
                    strategy_name="rsi",
                    interval_seconds=0,
                    quantity=1,
                    cron=None,
                ))
        finally:
            sched.shutdown()

    def test_remove_job(self):
        sched, *_ = _make_scheduler()
        sched._scheduler.start()
        try:
            sched.add_job(JobConfig("005930", "rsi", 300, 1))
            sched.remove_job("005930_rsi")
            assert sched._scheduler.get_job("005930_rsi") is None
        finally:
            sched.shutdown()

    def test_remove_nonexistent_raises(self):
        sched, *_ = _make_scheduler()
        sched._scheduler.start()
        try:
            with pytest.raises(KeyError):
                sched.remove_job("no_such_job")
        finally:
            sched.shutdown()

    def test_replace_existing_job(self):
        sched, *_ = _make_scheduler()
        sched._scheduler.start()
        try:
            sched.add_job(JobConfig("005930", "rsi", 300, 1))
            sched.add_job(JobConfig("005930", "rsi", 600, 2))  # 교체
            jobs = sched.list_jobs()
            assert len([j for j in jobs if j["job_id"] == "005930_rsi"]) == 1
        finally:
            sched.shutdown()


class TestExecution:
    @pytest.mark.asyncio
    async def test_hold_signal_no_order(self):
        sched, market_api, orders_api, notifier, mock_strategy = _make_scheduler(Signal.HOLD)
        sched._scheduler.start()

        with patch.dict("app.services.scheduler._STRATEGIES", {"rsi": mock_strategy}):
            cfg = JobConfig("005930", "rsi", 300, 1)
            sched._configs["005930_rsi"] = cfg
            sched._history["005930_rsi"] = __import__("collections").deque(maxlen=50)

            record = await sched._execute("005930_rsi", cfg)

        assert record.signal == "hold"
        orders_api.buy_market.assert_not_called()
        orders_api.sell_market.assert_not_called()
        notifier.notify_order.assert_not_called()
        sched.shutdown()

    @pytest.mark.asyncio
    async def test_buy_signal_places_order(self):
        sched, market_api, orders_api, notifier, mock_strategy = _make_scheduler(Signal.BUY)
        orders_api.buy_market.return_value = {"order_no": "12345"}
        sched._scheduler.start()

        with patch.dict("app.services.scheduler._STRATEGIES", {"rsi": mock_strategy}):
            cfg = JobConfig("005930", "rsi", 300, 5)
            sched._configs["005930_rsi"] = cfg
            sched._history["005930_rsi"] = __import__("collections").deque(maxlen=50)

            record = await sched._execute("005930_rsi", cfg)

        assert record.signal == "buy"
        orders_api.buy_market.assert_called_once_with("005930", 5)
        notifier.notify_order.assert_called_once()
        sched.shutdown()

    @pytest.mark.asyncio
    async def test_sell_signal_places_order(self):
        sched, market_api, orders_api, notifier, mock_strategy = _make_scheduler(Signal.SELL)
        orders_api.sell_market.return_value = {"order_no": "67890"}
        sched._scheduler.start()

        with patch.dict("app.services.scheduler._STRATEGIES", {"rsi": mock_strategy}):
            cfg = JobConfig("005930", "rsi", 300, 3)
            sched._configs["005930_rsi"] = cfg
            sched._history["005930_rsi"] = __import__("collections").deque(maxlen=50)

            record = await sched._execute("005930_rsi", cfg)

        assert record.signal == "sell"
        orders_api.sell_market.assert_called_once_with("005930", 3)
        sched.shutdown()

    @pytest.mark.asyncio
    async def test_api_error_returns_error_record(self):
        sched, market_api, orders_api, notifier, _ = _make_scheduler()
        market_api.get_daily_ohlcv.side_effect = RuntimeError("API 타임아웃")
        sched._scheduler.start()

        cfg = JobConfig("005930", "rsi", 300, 1)
        sched._configs["005930_rsi"] = cfg
        sched._history["005930_rsi"] = __import__("collections").deque(maxlen=50)

        record = await sched._execute("005930_rsi", cfg)

        assert record.signal == "error"
        assert record.error is not None
        notifier.notify_error.assert_called_once()
        sched.shutdown()

    @pytest.mark.asyncio
    async def test_history_accumulates(self):
        sched, market_api, orders_api, notifier, mock_strategy = _make_scheduler(Signal.HOLD)
        sched._scheduler.start()

        with patch.dict("app.services.scheduler._STRATEGIES", {"rsi": mock_strategy}):
            cfg = JobConfig("005930", "rsi", 300, 1)
            sched._configs["005930_rsi"] = cfg
            sched._history["005930_rsi"] = __import__("collections").deque(maxlen=50)

            for _ in range(3):
                await sched._execute("005930_rsi", cfg)

        assert len(sched.get_history("005930_rsi")) == 3
        sched.shutdown()
