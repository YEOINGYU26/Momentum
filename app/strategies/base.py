from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Optional

import pandas as pd


class Signal(Enum):
    BUY = "buy"
    SELL = "sell"
    HOLD = "hold"


@dataclass
class StrategyResult:
    signal: Signal
    reason: str
    confidence: float = 1.0
    suggested_price: Optional[int] = None


class BaseStrategy(ABC):
    """모든 전략의 기본 클래스"""

    name: str = "base"

    @abstractmethod
    def analyze(self, df: pd.DataFrame) -> StrategyResult:
        """
        df: OHLCV 데이터프레임
            columns: date, open, high, low, close, volume
        """
        ...
