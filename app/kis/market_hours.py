"""
한국 주식시장(KRX) 거래시간 유틸리티

정규장:         평일 09:00 ~ 15:20 (KST)  ord_dvsn="00"
종가동시호가:   15:20 ~ 15:30              주문 불가
장후 시간외:    15:30 ~ 18:00              ord_dvsn="06"
장전 시간외:    07:30 ~ 09:00              ord_dvsn="05"

공휴일 처리: 기본 제외 목록 미포함 (KIS API가 해당 에러 반환 → 상위에서 처리)
"""
from datetime import datetime, time
from typing import Optional

import pytz

KST = pytz.timezone("Asia/Seoul")


def now_kst() -> datetime:
    return datetime.now(KST)


def market_status(dt: Optional[datetime] = None) -> str:
    """
    현재 장 상태 반환:
      open        정규장 (09:00 ~ 15:20)
      closing     종가동시호가 (15:20 ~ 15:30)  — 주문 불가
      after_hours 장후 시간외 단일가 (15:30 ~ 18:00)  ord_dvsn="06"
      pre_market  장전 시간외 단일가 (07:30 ~ 09:00)  ord_dvsn="05"
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


def is_market_open(dt: Optional[datetime] = None) -> bool:
    """정규장 여부 (09:00~15:20)"""
    return market_status(dt) == "open"


def is_after_hours(dt: Optional[datetime] = None) -> bool:
    """장후 시간외 단일가 여부 (15:30~18:00)"""
    return market_status(dt) == "after_hours"


def is_pre_market(dt: Optional[datetime] = None) -> bool:
    """장전 시간외 단일가 여부 (07:30~09:00)"""
    return market_status(dt) == "pre_market"


def is_tradeable(dt: Optional[datetime] = None) -> bool:
    """주문 가능 시간 여부 (정규장 + 장전/장후 시간외)"""
    return market_status(dt) in ("open", "pre_market", "after_hours")
