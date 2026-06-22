from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from app.core.dependencies import get_condition_service
from app.services.condition_service import CompoundRule, ConditionService, IndicatorCondition, LineCondition

router = APIRouter(prefix="/conditions", tags=["conditions"])


# ── 요청 모델 ─────────────────────────────────────────────────────────────────

class LineConditionIn(BaseModel):
    start_time: int
    start_price: float
    end_time: int
    end_price: float


class IndicatorConditionIn(BaseModel):
    type: str = Field(..., pattern="^(rsi|moving_average|scalping)$")
    rsi_buy_thr: float = Field(default=30.0, ge=1, le=49)
    rsi_sell_thr: float = Field(default=70.0, ge=51, le=99)


class CompoundRuleRequest(BaseModel):
    ticker: str
    side: str = Field(..., pattern="^(buy|sell)$")
    quantity: int = Field(..., gt=0)
    interval_seconds: int = Field(default=60, ge=30)
    timeframe: str = Field(default="D", pattern="^(D|W|M|Y)$")
    line_conditions: list[LineConditionIn] = Field(default_factory=list)
    indicator_conditions: list[IndicatorConditionIn] = Field(default_factory=list)


# ── 엔드포인트 ────────────────────────────────────────────────────────────────

@router.get("")
async def list_rules(svc: ConditionService = Depends(get_condition_service)):
    return svc.list_rules()


@router.post("", status_code=201)
async def add_rule(
    req: CompoundRuleRequest,
    svc: ConditionService = Depends(get_condition_service),
):
    if not req.line_conditions and not req.indicator_conditions:
        raise HTTPException(status_code=422, detail="조건을 하나 이상 설정해야 합니다")

    rule = CompoundRule(
        ticker=req.ticker.upper(),
        side=req.side,
        quantity=req.quantity,
        interval_seconds=req.interval_seconds,
        timeframe=req.timeframe,
        line_conditions=[
            LineCondition(
                start_time=lc.start_time,
                start_price=lc.start_price,
                end_time=lc.end_time,
                end_price=lc.end_price,
            )
            for lc in req.line_conditions
        ],
        indicator_conditions=[
            IndicatorCondition(
                type=ic.type,
                rsi_buy_thr=ic.rsi_buy_thr,
                rsi_sell_thr=ic.rsi_sell_thr,
            )
            for ic in req.indicator_conditions
        ],
    )
    svc.add_rule(rule)
    return rule.to_dict()


@router.delete("/{rule_id}", status_code=204)
async def delete_rule(
    rule_id: str,
    svc: ConditionService = Depends(get_condition_service),
):
    if not svc.remove_rule(rule_id):
        raise HTTPException(status_code=404, detail="규칙을 찾을 수 없습니다")
