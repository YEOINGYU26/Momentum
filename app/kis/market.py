from app.kis.client import KISClient


class MarketAPI:
    """시세 조회 관련 KIS API"""

    # 모의/실거래 공통 tr_id
    _TR_PRICE = "FHKST01010100"
    _TR_DAILY_PRICE = "FHKST01010400"

    def __init__(self, client: KISClient):
        self._client = client

    async def get_price(self, ticker: str) -> dict:
        """현재가 조회"""
        params = {
            "fid_cond_mrkt_div_code": "J",
            "fid_input_iscd": ticker,
        }
        body = await self._client.get(
            "/uapi/domestic-stock/v1/quotations/inquire-price",
            self._TR_PRICE,
            params,
        )
        output = body.get("output", {})
        return {
            "ticker": ticker,
            "current_price": int(output.get("stck_prpr", 0)),
            "open_price": int(output.get("stck_oprc", 0)),
            "high_price": int(output.get("stck_hgpr", 0)),
            "low_price": int(output.get("stck_lwpr", 0)),
            "volume": int(output.get("acml_vol", 0)),
            "change_rate": float(output.get("prdy_ctrt", 0)),
            "trade_time": output.get("stck_shrn_iscd", ""),
        }

    async def get_daily_ohlcv(self, ticker: str, period: str = "D") -> list[dict]:
        """일/주/월봉 데이터 조회 (period: D/W/M)"""
        params = {
            "fid_cond_mrkt_div_code": "J",
            "fid_input_iscd": ticker,
            "fid_period_div_code": period,
            "fid_org_adj_prc": "0",
        }
        body = await self._client.get(
            "/uapi/domestic-stock/v1/quotations/inquire-daily-price",
            self._TR_DAILY_PRICE,
            params,
        )
        rows = body.get("output2", [])
        return [
            {
                "date": r.get("stck_bsop_date", ""),
                "open": int(r.get("stck_oprc", 0)),
                "high": int(r.get("stck_hgpr", 0)),
                "low": int(r.get("stck_lwpr", 0)),
                "close": int(r.get("stck_clpr", 0)),
                "volume": int(r.get("acml_vol", 0)),
            }
            for r in rows
        ]
