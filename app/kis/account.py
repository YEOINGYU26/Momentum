from app.kis.client import KISClient
from app.core.config import Settings

_TR_BALANCE_MOCK = "VTTC8434R"
_TR_BALANCE_REAL = "TTTC8434R"


class AccountAPI:
    """계좌 조회 관련 KIS API"""

    def __init__(self, client: KISClient, settings: Settings):
        self._client = client
        self._settings = settings

    def _tr_balance(self) -> str:
        return _TR_BALANCE_MOCK if self._settings.kis_is_mock else _TR_BALANCE_REAL

    async def get_balance(self) -> dict:
        """잔고 조회 — 보유 종목 + 예수금"""
        params = {
            "CANO": self._settings.kis_account_no,
            "ACNT_PRDT_CD": self._settings.kis_account_product_code,
            "AFHR_FLPR_YN": "N",
            "OFL_YN": "",
            "INQR_DVSN": "02",
            "UNPR_DVSN": "01",
            "FUND_STTL_ICLD_YN": "N",
            "FNCG_AMT_AUTO_RDPT_YN": "N",
            "PRCS_DVSN": "01",
            "CTX_AREA_FK100": "",
            "CTX_AREA_NK100": "",
        }
        body = await self._client.get(
            "/uapi/domestic-stock/v1/trading/inquire-balance",
            self._tr_balance(),
            params,
        )
        holdings = [
            {
                "ticker": item.get("pdno", ""),
                "name": item.get("prdt_name", ""),
                "quantity": int(item.get("hldg_qty", 0)),
                "avg_price": float(item.get("pchs_avg_pric", 0)),
                "current_price": int(item.get("prpr", 0)),
                "eval_profit_loss": int(item.get("evlu_pfls_amt", 0)),
                "eval_profit_loss_rate": float(item.get("evlu_pfls_rt", 0)),
            }
            for item in body.get("output1", [])
            if int(item.get("hldg_qty", 0)) > 0
        ]
        summary = body.get("output2", [{}])[0]
        return {
            "holdings": holdings,
            "total_eval_amount": int(summary.get("tot_evlu_amt", 0)),
            "available_cash": int(summary.get("nxdy_excc_amt", 0)),
            "total_profit_loss": int(summary.get("evlu_pfls_smtl_amt", 0)),
        }
