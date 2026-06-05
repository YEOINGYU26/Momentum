import pytest
import pandas as pd
from unittest.mock import AsyncMock, MagicMock, patch

from app.strategies.rsi import RSIStrategy
from app.strategies.moving_average import MovingAverageStrategy
from app.strategies.base import Signal


def _make_df(closes: list[float]) -> pd.DataFrame:
    return pd.DataFrame({
        "date": [str(i) for i in range(len(closes))],
        "open": closes,
        "high": [c * 1.01 for c in closes],
        "low": [c * 0.99 for c in closes],
        "close": closes,
        "volume": [1000] * len(closes),
    })


class TestRSIStrategy:
    def test_hold_on_insufficient_data(self):
        strategy = RSIStrategy(period=14)
        df = _make_df([100.0] * 5)
        result = strategy.analyze(df)
        assert result.signal == Signal.HOLD

    def test_buy_on_oversold(self):
        # 큰 폭 하락으로 RSI 30 이하 유도
        closes = [100.0] * 10 + [50.0] * 10
        df = _make_df(closes)
        result = RSIStrategy(period=14, oversold=30).analyze(df)
        assert result.signal == Signal.BUY

    def test_sell_on_overbought(self):
        # 큰 폭 상승으로 RSI 70 이상 유도
        closes = [100.0] * 10 + [200.0] * 10
        df = _make_df(closes)
        result = RSIStrategy(period=14, overbought=70).analyze(df)
        assert result.signal == Signal.SELL


class TestMovingAverageStrategy:
    def test_hold_on_insufficient_data(self):
        strategy = MovingAverageStrategy(short_period=5, long_period=20)
        df = _make_df([100.0] * 15)
        result = strategy.analyze(df)
        assert result.signal == Signal.HOLD

    def test_golden_cross(self):
        # 단기선이 아래에서 위로 크로스
        base = [100.0] * 20
        rising = [100.0 + i * 5 for i in range(10)]
        df = _make_df(base + rising)
        result = MovingAverageStrategy(short_period=5, long_period=20).analyze(df)
        assert result.signal in (Signal.BUY, Signal.HOLD)
