from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.dependencies import get_push_notifier
from app.services.push import PushNotifier

router = APIRouter(prefix="/devices", tags=["devices"])


class DeviceTokenBody(BaseModel):
    token: str


@router.post("/token", status_code=201)
async def register_token(
    body: DeviceTokenBody,
    push: PushNotifier = Depends(get_push_notifier),
):
    push.register_token(body.token)
    return {"registered": True, "token_count": len(push.list_tokens())}


@router.delete("/token")
async def unregister_token(
    body: DeviceTokenBody,
    push: PushNotifier = Depends(get_push_notifier),
):
    push.unregister_token(body.token)
    return {"unregistered": True, "token_count": len(push.list_tokens())}


@router.get("/tokens")
async def list_tokens(push: PushNotifier = Depends(get_push_notifier)):
    tokens = push.list_tokens()
    return {"tokens": tokens, "count": len(tokens)}
