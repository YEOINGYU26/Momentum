import json
import time
from pathlib import Path

import httpx

from app.core.config import Settings

_CACHE_FILE = Path("kistoken_cache.json")


class KISAuth:
    """KIS OAuth 토큰 관리 — 만료 전 자동 갱신"""

    def __init__(self, settings: Settings):
        self._settings = settings
        self._access_token: str = ""
        self._expires_at: float = 0.0

    @property
    def access_token(self) -> str:
        return self._access_token

    @property
    def is_valid(self) -> bool:
        return bool(self._access_token) and time.time() < self._expires_at - 60

    def load_from_cache(self) -> bool:
        if not _CACHE_FILE.exists():
            return False
        try:
            data = json.loads(_CACHE_FILE.read_text())
            if data.get("app_key") != self._settings.kis_app_key:
                return False
            if time.time() >= data.get("expires_at", 0) - 60:
                return False
            self._access_token = data["access_token"]
            self._expires_at = data["expires_at"]
            return True
        except Exception:
            return False

    def save_to_cache(self) -> None:
        _CACHE_FILE.write_text(
            json.dumps(
                {
                    "app_key": self._settings.kis_app_key,
                    "access_token": self._access_token,
                    "expires_at": self._expires_at,
                }
            )
        )

    async def issue_token(self) -> None:
        """신규 액세스 토큰 발급"""
        url = f"{self._settings.kis_base_url}/oauth2/tokenP"
        payload = {
            "grant_type": "client_credentials",
            "appkey": self._settings.kis_app_key,
            "appsecret": self._settings.kis_app_secret,
        }
        async with httpx.AsyncClient() as client:
            resp = await client.post(url, json=payload, timeout=10)
            resp.raise_for_status()
            body = resp.json()

        self._access_token = body["access_token"]
        # KIS는 expires_in(초) 또는 access_token_token_expired(datetime 문자열) 반환
        expires_in = int(body.get("expires_in", 86400))
        self._expires_at = time.time() + expires_in
        self.save_to_cache()

    async def ensure_token(self) -> str:
        if self.is_valid:
            return self._access_token
        if self.load_from_cache():
            return self._access_token
        await self.issue_token()
        return self._access_token
