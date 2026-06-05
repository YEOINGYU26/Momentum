from typing import Any

import httpx

from app.core.config import Settings
from app.kis.auth import KISAuth


class KISClient:
    """KIS REST API 기본 HTTP 클라이언트"""

    def __init__(self, settings: Settings):
        self._settings = settings
        self._auth = KISAuth(settings)
        self._base_url = settings.kis_base_url

    def _common_headers(self, token: str, tr_id: str, custtype: str = "P") -> dict:
        return {
            "content-type": "application/json; charset=utf-8",
            "authorization": f"Bearer {token}",
            "appkey": self._settings.kis_app_key,
            "appsecret": self._settings.kis_app_secret,
            "tr_id": tr_id,
            "custtype": custtype,
        }

    async def get(self, path: str, tr_id: str, params: dict) -> dict[str, Any]:
        token = await self._auth.ensure_token()
        url = f"{self._base_url}{path}"
        headers = self._common_headers(token, tr_id)
        async with httpx.AsyncClient(verify=False) as client:
            resp = await client.get(url, headers=headers, params=params, timeout=10)
            resp.raise_for_status()
            body = resp.json()
        _raise_if_error(body)
        return body

    async def post(self, path: str, tr_id: str, payload: dict) -> dict[str, Any]:
        token = await self._auth.ensure_token()
        url = f"{self._base_url}{path}"
        headers = self._common_headers(token, tr_id)
        async with httpx.AsyncClient(verify=False) as client:
            resp = await client.post(url, headers=headers, json=payload, timeout=10)
            resp.raise_for_status()
            body = resp.json()
        _raise_if_error(body)
        return body


def _raise_if_error(body: dict) -> None:
    rt_cd = body.get("rt_cd", "0")
    if rt_cd != "0":
        msg = body.get("msg1", "KIS API 오류")
        raise RuntimeError(f"[KIS {rt_cd}] {msg}")
