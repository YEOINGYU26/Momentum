import logging

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import account, market, orders, strategy, ws, scheduler
from app.core.config import get_settings
from app.core.dependencies import get_price_monitor, get_realtime_service, get_scheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logger.info("Trading Bot 시작 — 모의투자: %s", settings.kis_is_mock)
    monitor = get_price_monitor()
    monitor.start()
    realtime = get_realtime_service()
    realtime.start()
    sched = get_scheduler()
    sched.start()
    yield
    sched.shutdown()
    realtime.stop()
    monitor.stop()
    logger.info("Trading Bot 종료")


app = FastAPI(
    title="KIS Auto Trading Bot",
    description="한국투자증권 KIS API 기반 자동매매 시스템",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(market.router, prefix="/api/v1")
app.include_router(account.router, prefix="/api/v1")
app.include_router(orders.router, prefix="/api/v1")
app.include_router(strategy.router, prefix="/api/v1")
app.include_router(ws.router)  # /ws/* 경로는 prefix 없음
app.include_router(scheduler.router, prefix="/api/v1")


@app.get("/health")
async def health():
    settings = get_settings()
    return {
        "status": "ok",
        "mode": "mock" if settings.kis_is_mock else "real",
        "version": "0.1.0",
    }
