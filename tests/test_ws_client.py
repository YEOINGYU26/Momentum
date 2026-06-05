import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

from app.kis.ws_client import _parse_price_message, PriceUpdate, KISWebSocketClient


class TestParseMessage:
    def test_valid_price_message(self):
        # 실제 KIS 메시지 형식: encrypt|tr_id|cnt|fields^...
        raw = "0|H0STCNT0|001|005930^094512^72000^2^500^0.70^71800^71500^72300^71200^72100^71900^1234^5678900^4098000000^0^0^0"
        update = _parse_price_message(raw)
        assert update is not None
        assert update.ticker == "005930"
        assert update.time == "094512"
        assert update.price == 72000
        assert update.change == 500
        assert update.open == 71500
        assert update.high == 72300
        assert update.low == 71200
        assert update.ask == 72100
        assert update.bid == 71900
        assert update.volume == 1234
        assert update.cumulative_volume == 5678900

    def test_wrong_tr_id_returns_none(self):
        raw = "0|H0STASP0|001|005930^094512^72000"
        assert _parse_price_message(raw) is None

    def test_too_short_returns_none(self):
        assert _parse_price_message("0|H0STCNT0|001|005930^094512") is None

    def test_non_price_format_returns_none(self):
        assert _parse_price_message("{}") is None
        assert _parse_price_message("") is None


class TestKISWebSocketClient:
    @pytest.mark.asyncio
    async def test_subscribe_registers_ticker(self):
        settings = MagicMock()
        settings.kis_app_key = "key"
        settings.kis_app_secret = "secret"
        settings.kis_base_url = "https://mock.example.com"
        settings.kis_ws_url = "ws://mock.example.com"

        on_price = AsyncMock()
        client = KISWebSocketClient(settings, on_price)
        # WS가 없는 상태에서 구독 등록
        await client.subscribe("005930")
        assert "005930" in client._subscriptions

    @pytest.mark.asyncio
    async def test_unsubscribe_removes_ticker(self):
        settings = MagicMock()
        on_price = AsyncMock()
        client = KISWebSocketClient(settings, on_price)
        client._subscriptions.add("005930")
        await client.unsubscribe("005930")
        assert "005930" not in client._subscriptions

    @pytest.mark.asyncio
    async def test_handle_pingpong(self):
        """PINGPONG JSON 수신 시 그대로 pong 전송"""
        settings = MagicMock()
        on_price = AsyncMock()
        client = KISWebSocketClient(settings, on_price)

        mock_ws = AsyncMock()
        client._ws = mock_ws

        pingpong_msg = '{"header":{"tr_id":"PINGPONG"}}'
        await client._handle_message(pingpong_msg)
        mock_ws.send.assert_called_once_with(pingpong_msg)
        on_price.assert_not_called()

    @pytest.mark.asyncio
    async def test_handle_price_calls_callback(self):
        settings = MagicMock()
        on_price = AsyncMock()
        client = KISWebSocketClient(settings, on_price)
        client._ws = AsyncMock()

        raw = "0|H0STCNT0|001|005930^094512^72000^2^500^0.70^71800^71500^72300^71200^72100^71900^1234^5678900^4098000000^0^0^0"
        await client._handle_message(raw)
        on_price.assert_called_once()
        arg = on_price.call_args[0][0]
        assert isinstance(arg, PriceUpdate)
        assert arg.ticker == "005930"
