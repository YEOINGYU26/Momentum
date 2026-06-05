import pandas as pd
import ta

from app.strategies.base import BaseStrategy, Signal, StrategyResult


class RSIStrategy(BaseStrategy):
    name = "rsi"

    def __init__(self, period: int = 14, oversold: float = 30.0, overbought: float = 70.0):
        self.period = period
        self.oversold = oversold
        self.overbought = overbought

    def analyze(self, df: pd.DataFrame) -> StrategyResult:
        if len(df) < self.period + 1:
            return StrategyResult(Signal.HOLD, "데이터 부족")

        rsi = ta.momentum.RSIIndicator(df["close"], window=self.period).rsi()
        current = float(rsi.iloc[-1])

        if current <= self.oversold:
            return StrategyResult(
                Signal.BUY,
                f"RSI 과매도 ({current:.1f} ≤ {self.oversold})",
                confidence=min(1.0, (self.oversold - current) / self.oversold),
            )
        if current >= self.overbought:
            return StrategyResult(
                Signal.SELL,
                f"RSI 과매수 ({current:.1f} ≥ {self.overbought})",
                confidence=min(1.0, (current - self.overbought) / (100 - self.overbought)),
            )
        return StrategyResult(Signal.HOLD, f"RSI 중립 ({current:.1f})")
