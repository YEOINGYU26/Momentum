import pandas as pd
import ta

from app.strategies.base import BaseStrategy, Signal, StrategyResult


class ScalpingStrategy(BaseStrategy):
    """
    단기 스캘핑: Bollinger Band + Stochastic 결합
    - BB 하단 이탈 + Stochastic 과매도 -> BUY
    - BB 상단 돌파 + Stochastic 과매수 -> SELL
    """

    name = "scalping"

    def __init__(
        self,
        bb_period: int = 20,
        bb_std: float = 2.0,
        stoch_k: int = 14,
        stoch_d: int = 3,
        stoch_oversold: float = 20.0,
        stoch_overbought: float = 80.0,
    ):
        self.bb_period = bb_period
        self.bb_std = bb_std
        self.stoch_k = stoch_k
        self.stoch_d = stoch_d
        self.stoch_oversold = stoch_oversold
        self.stoch_overbought = stoch_overbought

    def analyze(self, df: pd.DataFrame) -> StrategyResult:
        if len(df) < max(self.bb_period, self.stoch_k) + 5:
            return StrategyResult(Signal.HOLD, "데이터 부족")

        bb = ta.volatility.BollingerBands(
            df["close"], window=self.bb_period, window_dev=self.bb_std
        )
        stoch = ta.momentum.StochasticOscillator(
            df["high"], df["low"], df["close"],
            window=self.stoch_k, smooth_window=self.stoch_d,
        )

        price = float(df["close"].iloc[-1])
        bb_lower = float(bb.bollinger_lband().iloc[-1])
        bb_upper = float(bb.bollinger_hband().iloc[-1])
        k_val = float(stoch.stoch().iloc[-1])

        if price <= bb_lower and k_val <= self.stoch_oversold:
            return StrategyResult(
                Signal.BUY,
                f"BB 하단({bb_lower:.0f}) 이탈 + Stoch K({k_val:.1f}) 과매도",
                confidence=0.8,
                suggested_price=int(price),
            )
        if price >= bb_upper and k_val >= self.stoch_overbought:
            return StrategyResult(
                Signal.SELL,
                f"BB 상단({bb_upper:.0f}) 돌파 + Stoch K({k_val:.1f}) 과매수",
                confidence=0.8,
                suggested_price=int(price),
            )
        return StrategyResult(Signal.HOLD, f"스캘핑 대기 (Price:{price:.0f}, K:{k_val:.1f})")
