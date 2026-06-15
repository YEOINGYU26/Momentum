from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # KIS API
    kis_app_key: str = ""
    kis_app_secret: str = ""
    kis_account_no: str = ""
    kis_account_product_code: str = "01"
    kis_is_mock: bool = False

    # FCM 네이티브 푸시
    fcm_credentials_path: str = ""  # Firebase 서비스 계정 JSON 경로

    # 서버
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    app_env: str = "development"

    @property
    def kis_base_url(self) -> str:
        if self.kis_is_mock:
            return "https://openapivts.koreainvestment.com:29443"
        return "https://openapi.koreainvestment.com:9443"

    @property
    def kis_ws_url(self) -> str:
        # 모의/실거래 공통 WebSocket 주소
        return "ws://ops.koreainvestment.com:21000"

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"


@lru_cache
def get_settings() -> Settings:
    return Settings()
