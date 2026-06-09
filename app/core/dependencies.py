from functools import lru_cache

from app.core.config import get_settings
from app.kis.client import KISClient
from app.kis.market import MarketAPI
from app.kis.orders import OrdersAPI
from app.kis.account import AccountAPI
from app.services.push import PushNotifier
from app.services.price_monitor import PriceMonitorService
from app.services.realtime import RealtimeService
from app.services.scheduler import StrategyScheduler


@lru_cache
def get_kis_client() -> KISClient:
    return KISClient(get_settings())


@lru_cache
def get_market_api() -> MarketAPI:
    return MarketAPI(get_kis_client())


@lru_cache
def get_orders_api() -> OrdersAPI:
    return OrdersAPI(get_kis_client(), get_settings())


@lru_cache
def get_account_api() -> AccountAPI:
    return AccountAPI(get_kis_client(), get_settings())


@lru_cache
def get_push_notifier() -> PushNotifier:
    return PushNotifier(get_settings())


@lru_cache
def get_price_monitor() -> PriceMonitorService:
    return PriceMonitorService(
        market_api=get_market_api(),
        orders_api=get_orders_api(),
        notifier=get_push_notifier(),
    )


@lru_cache
def get_realtime_service() -> RealtimeService:
    return RealtimeService(get_settings())


@lru_cache
def get_scheduler() -> StrategyScheduler:
    return StrategyScheduler(
        market_api=get_market_api(),
        orders_api=get_orders_api(),
        notifier=get_push_notifier(),
    )
