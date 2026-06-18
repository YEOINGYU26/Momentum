"""
한국 주식시장(KRX) 거래시간 유틸리티

정규장 기준:  평일 09:00 ~ 15:20 (KST)
  - 15:20~15:30 종가동시호가 구간은 지정가 주문 제한 가능성이 있어 제외
  - 공휴일 처리: 기본 제외 목록 미포함 (KIS API가 해당 에러 반환 → 상위에서 처리)
"""
from datetime import datetime, time

import pytz

KST = pytz.timezone("Asia/Seoul")

_OPEN  = time(9, 0)
_CLOSE = time(15, 20)   # 동시호가 시작 전에 마감 (안전 마진)


def now_kst() -> datetime:
    return datetime.now(KST)


def is_market_open(dt: datetime | None = None) -> bool:
    """주어진 시각(기본: 현재)이 정규 장중인지 반환"""
    now = dt or now_kst()
    if now.weekday() >= 5:          # 토(5) · 일(6)
        return False
    t = now.time()
    return _OPEN <= t <= _CLOSE


def market_status(dt: datetime | None = None) -> str:
    """
    현재 장 상태 반환:
      open        정규장 (09:00 ~ 15:20)
      closing     종가동시호가 (15:20 ~ 15:30)
      after_hours 시간외 단일가 (15:30 ~ 18:00)
      pre_market  장전 단일가 / 시간외 (07:30 ~ 09:00)
      closed      장 마감 / 주말
    """
    now = dt or now_kst()
    if now.weekday() >= 5:
        return "closed"
    t = now.time()
    if time(7, 30) <= t < time(9, 0):
        return "pre_market"
    if time(9, 0) <= t < time(15, 20):
        return "open"
    if time(15, 20) <= t < time(15, 30):
        return "closing"
    if time(15, 30) <= t < time(18, 0):
        return "after_hours"
    return "closed"
