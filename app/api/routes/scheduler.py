from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from app.core.dependencies import get_scheduler
from app.services.scheduler import JobConfig, StrategyScheduler

router = APIRouter(prefix="/scheduler", tags=["scheduler"])


class AddJobRequest(BaseModel):
    ticker: str = Field(..., examples=["005930"])
    strategy_name: str = Field(..., examples=["rsi"])
    interval_seconds: int = Field(default=300, ge=0, description="0이면 cron 사용")
    quantity: int = Field(default=1, gt=0)
    data_interval: str = Field(default="D", pattern="^(D|W|M)$", description="D=일봉, W=주봉, M=월봉")
    cron: Optional[str] = Field(default=None, examples=["*/5 9-15 * * 1-5"])


@router.post("/jobs", status_code=201)
async def add_job(
    req: AddJobRequest,
    sched: StrategyScheduler = Depends(get_scheduler),
):
    try:
        job_id = sched.add_job(
            JobConfig(
                ticker=req.ticker,
                strategy_name=req.strategy_name,
                interval_seconds=req.interval_seconds,
                quantity=req.quantity,
                data_interval=req.data_interval,
                cron=req.cron,
            )
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"job_id": job_id}


@router.get("/jobs")
async def list_jobs(sched: StrategyScheduler = Depends(get_scheduler)):
    return sched.list_jobs()


@router.delete("/jobs/{job_id}")
async def remove_job(
    job_id: str,
    sched: StrategyScheduler = Depends(get_scheduler),
):
    try:
        sched.remove_job(job_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"removed": job_id}


@router.post("/jobs/{job_id}/pause")
async def pause_job(
    job_id: str,
    sched: StrategyScheduler = Depends(get_scheduler),
):
    try:
        sched.pause_job(job_id)
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"paused": job_id}


@router.post("/jobs/{job_id}/resume")
async def resume_job(
    job_id: str,
    sched: StrategyScheduler = Depends(get_scheduler),
):
    try:
        sched.resume_job(job_id)
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"resumed": job_id}


@router.post("/jobs/{job_id}/run")
async def run_now(
    job_id: str,
    sched: StrategyScheduler = Depends(get_scheduler),
):
    """등록된 잡을 즉시 1회 실행"""
    try:
        record = await sched.run_now(job_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return record.__dict__


@router.get("/jobs/{job_id}/history")
async def job_history(
    job_id: str,
    sched: StrategyScheduler = Depends(get_scheduler),
):
    history = sched.get_history(job_id)
    if not history and job_id not in {j["job_id"] for j in sched.list_jobs()}:
        raise HTTPException(status_code=404, detail=f"잡 없음: {job_id}")
    return [r.__dict__ for r in history]
