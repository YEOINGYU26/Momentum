from fastapi import APIRouter, Depends

from app.core.dependencies import get_account_api
from app.kis.account import AccountAPI

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/balance")
async def get_balance(api: AccountAPI = Depends(get_account_api)):
    return await api.get_balance()
