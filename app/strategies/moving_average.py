import pandas as pd

from app.strategies.base import BaseStrategy, Signal, StrategyResult


class MovingAverageStrategy(BaseStrategy):
    """단기 MA가 장기 MA를 골든크로스/데드크로스할 때 시그널"""

    name = "moving_average"

    def __init__(self, short_period: int = 5, long_period: int = 20):
        self.short_period = short_period
        self.long_period = long_period

    def analyze(self, df: pd.DataFrame) -> StrategyResult:
        if len(df) < self.long_period + 1:
            return StrategyResult(Signal.HOLD, "데이터 부족")

        close = df["close"]
        ma_short = close.rolling(self.short_period).mean()
        ma_long = close.rolling(self.long_period).mean()

        prev_short = float(ma_short.iloc[-2])
        prev_long = float(ma_long.iloc[-2])
        curr_short = float(ma_short.iloc[-1])
        curr_long = float(ma_long.iloc[-1])

        # 골든크로스
        if prev_short <= prev_long and curr_short > curr_long:
            return StrategyResult(
                Signal.BUY,
                f"골든크로스 MA{self.short_period}({curr_short:.0f}) > MA{self.long_period}({curr_long:.0f})",
            )
        # 데드크로스
        if prev_short >= prev_long and curr_short < curr_long:
            return StrategyResult(
                Signal.SELL,
                f"데드크로스 MA{self.short_period}({curr_short:.0f}) < MA{self.long_period}({curr_long:.0f})",
            )

        direction = "위" if curr_short > curr_long else "아래"
        return StrategyResult(
            Signal.HOLD,
            f"MA{self.short_period} 장기선 {direction} — 크로스 없음",
        )
