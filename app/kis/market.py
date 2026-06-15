from datetime import date, datetime, time as dtime, timedelta

from app.kis.client import KISClient


class MarketAPI:
    _TR_PRICE = "FHKST01010100"
    _TR_DAILY_CHART = "FHKST03010100"
    _TR_MINUTE_CHART = "FHKST03010200"

    def __init__(self, client: KISClient):
        self._client = client

    async def get_price(self, ticker: str) -> dict:
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
        sign = output.get("prdy_vrss_sign", "3")
        is_down = sign in ("4", "5")
        change_abs = int(output.get("prdy_vrss", 0) or 0)
        change = -change_abs if is_down else change_abs
        return {
            "ticker": ticker,
            "current_price": int(output.get("stck_prpr", 0) or 0),
            "open_price": int(output.get("stck_oprc", 0) or 0),
            "high_price": int(output.get("stck_hgpr", 0) or 0),
            "low_price": int(output.get("stck_lwpr", 0) or 0),
            "volume": int(output.get("acml_vol", 0) or 0),
            "change": change,
            "change_sign": sign,   # 1=상한 2=상승 3=보합 4=하락 5=하한
            "change_rate": (-1 if is_down else 1) * float(output.get("prdy_ctrt", 0) or 0),
        }

    async def get_daily_ohlcv(self, ticker: str, period: str = "D") -> list[dict]:
        """1회 호출 — 일/주/월봉"""
        end = date.today().strftime("%Y%m%d")
        start = "19000101"
        params = {
            "fid_cond_mrkt_div_code": "J",
            "fid_input_iscd": ticker,
            "fid_period_div_code": period,
            "fid_org_adj_prc": "0",
            "fid_input_date_1": start,
            "fid_input_date_2": end,
        }
        body = await self._client.get(
            "/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
            self._TR_DAILY_CHART,
            params,
        )
        rows = body.get("output2", [])
        return self._rows_to_dicts(rows)

    async def get_daily_ohlcv_all(self, ticker: str, period: str = "D") -> list[dict]:
        """페이지네이션으로 전체 기간 조회"""
        all_rows: list[dict] = []
        seen: set[str] = set()
        end = date.today()
        max_pages = {"D": 10, "W": 5, "M": 3}.get(period, 5)

        for _ in range(max_pages):
            start_dt = max(end - timedelta(days=3650), date(1990, 1, 1))
            params = {
                "fid_cond_mrkt_div_code": "J",
                "fid_input_iscd": ticker,
                "fid_period_div_code": period,
                "fid_org_adj_prc": "0",
                "fid_input_date_1": start_dt.strftime("%Y%m%d"),
                "fid_input_date_2": end.strftime("%Y%m%d"),
            }
            try:
                body = await self._client.get(
                    "/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
                    self._TR_DAILY_CHART,
                    params,
                )
            except Exception:
                break

            rows = body.get("output2", [])
            if not rows:
                break

            new = 0
            for r in rows:
                d_str = r.get("stck_bsop_date", "")
                if d_str and d_str not in seen:
                    seen.add(d_str)
                    all_rows.append(r)
                    new += 1

            if new == 0:
                break

            oldest_str = rows[-1].get("stck_bsop_date", "")
            if not oldest_str or len(oldest_str) != 8:
                break
            oldest = date(int(oldest_str[:4]), int(oldest_str[4:6]), int(oldest_str[6:8]))
            end = oldest - timedelta(days=1)
            if end < date(1990, 1, 1):
                break

        all_rows.sort(key=lambda r: r.get("stck_bsop_date", ""))
        return self._rows_to_dicts(all_rows)

    async def get_yearly_ohlcv(self, ticker: str) -> list[dict]:
        """연봉 — 월봉 집계"""
        monthly = await self.get_daily_ohlcv_all(ticker, "M")
        yearly: dict[str, dict] = {}
        for r in monthly:
            year = r["date"][:4]
            if year not in yearly:
                yearly[year] = {
                    "date": year + "0101",
                    "open": r["open"], "high": r["high"],
                    "low": r["low"],   "close": r["close"],
                    "volume": r["volume"],
                }
            else:
                yearly[year]["high"]   = max(yearly[year]["high"], r["high"])
                yearly[year]["low"]    = min(yearly[year]["low"],  r["low"])
                yearly[year]["close"]  = r["close"]
                yearly[year]["volume"] += r["volume"]
        return sorted(yearly.values(), key=lambda r: r["date"])

    async def get_minute_ohlcv(self, ticker: str, interval_minutes: int = 1, calls: int = 1) -> list[dict]:
        raw = await self._fetch_1min_batch(ticker, calls=calls)
        if interval_minutes <= 1:
            return raw
        return self._aggregate_candles(raw, interval_minutes)

    async def _fetch_1min_batch(self, ticker: str, calls: int = 1) -> list[dict]:
        now = datetime.now()
        today = now.strftime("%Y%m%d")
        ref = now if dtime(9, 0) <= now.time() <= dtime(15, 30) \
              else now.replace(hour=15, minute=30, second=0, microsecond=0)

        seen: set[str] = set()
        all_rows: list[dict] = []

        for _ in range(calls):
            params = {
                "fid_etc_cls_code": "",
                "fid_cond_mrkt_div_code": "J",
                "fid_input_iscd": ticker,
                "fid_input_hour_1": ref.strftime("%H%M%S"),
                "fid_pw_data_incu_yn": "Y",
            }
            try:
                body = await self._client.get(
                    "/uapi/domestic-stock/v1/quotations/inquire-time-itemchartprice",
                    self._TR_MINUTE_CHART,
                    params,
                )
            except Exception:
                break

            rows = body.get("output2", [])
            if not rows:
                break

            for r in rows:
                key = r.get("stck_cntg_hour", "")
                if key and key not in seen:
                    seen.add(key)
                    all_rows.append({
                        "datetime": today + key,
                        "open":   int(r.get("stck_oprc", 0) or 0),
                        "high":   int(r.get("stck_hgpr", 0) or 0),
                        "low":    int(r.get("stck_lwpr", 0) or 0),
                        "close":  int(r.get("stck_prpr", 0) or 0),
                        "volume": int(r.get("cntg_vol",  0) or 0),
                    })

            oldest = rows[-1].get("stck_cntg_hour", "090000")
            h, m = int(oldest[:2]), int(oldest[2:4])
            ref = ref.replace(hour=h, minute=m, second=0) - timedelta(minutes=1)
            if ref.time() < dtime(9, 0):
                break

        all_rows.sort(key=lambda r: r["datetime"])
        return all_rows

    def _aggregate_candles(self, rows: list[dict], minutes: int) -> list[dict]:
        result: list[dict] = []
        bucket: list[dict] = []
        bucket_key: tuple | None = None

        for row in rows:
            ds = row.get("datetime", "")
            if len(ds) < 12:
                continue
            try:
                total_min = int(ds[8:10]) * 60 + int(ds[10:12])
            except ValueError:
                continue
            slot_min = (total_min // minutes) * minutes
            key = (ds[:8], slot_min)
            if bucket_key != key:
                if bucket:
                    result.append(self._merge_bucket(bucket, bucket_key))
                bucket = [row]
                bucket_key = key
            else:
                bucket.append(row)

        if bucket:
            result.append(self._merge_bucket(bucket, bucket_key))
        return result

    @staticmethod
    def _merge_bucket(rows: list[dict], key: tuple) -> dict:
        date_str, slot_min = key
        h, m = divmod(slot_min, 60)
        return {
            "datetime": date_str + f"{h:02d}{m:02d}00",
            "open":   rows[0]["open"],
            "high":   max(r["high"] for r in rows),
            "low":    min(r["low"]  for r in rows),
            "close":  rows[-1]["close"],
            "volume": sum(r["volume"] for r in rows),
        }

    @staticmethod
    def _rows_to_dicts(rows: list) -> list[dict]:
        return [
            {
                "date":   r.get("stck_bsop_date", ""),
                "open":   int(r.get("stck_oprc", 0) or 0),
                "high":   int(r.get("stck_hgpr", 0) or 0),
                "low":    int(r.get("stck_lwpr", 0) or 0),
                "close":  int(r.get("stck_clpr", 0) or 0),
                "volume": int(r.get("acml_vol",  0) or 0),
            }
            for r in rows
        ]
