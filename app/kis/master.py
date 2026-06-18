"""
KIS 종목 마스터 로더

우선순위:
1. app/data/stock_db.json  (FinanceDataReader로 생성한 로컬 파일, 항상 존재)
2. KIS 마스터 ZIP 다운로드 (운영 서버에서 최신 데이터 갱신용, 실패해도 무관)
"""

import io
import json
import logging
import zipfile
from dataclasses import dataclass
from pathlib import Path

import httpx

logger = logging.getLogger(__name__)

_DB_PATH = Path(__file__).parent.parent / "data" / "stock_db.json"
_KOSPI_URL  = "https://new.real.download.dws.or.kr/common/master/kospi_code.mst.zip"
_KOSDAQ_URL = "https://new.real.download.dws.or.kr/common/master/kosdaq_code.mst.zip"

_TICKER_START = 0
_TICKER_END   = 9
_NAME_START   = 21
_NAME_END     = 61


@dataclass(frozen=True)
class MasterItem:
    ticker: str
    name: str
    exchange: str  # KOSPI | KOSDAQ


_cache: list[MasterItem] = []


async def load_master() -> int:
    """종목 DB 로드. stock_db.json → KIS 마스터 ZIP 순으로 시도."""
    global _cache

    # 1. 로컬 JSON 파일 (항상 있음)
    if _DB_PATH.exists():
        try:
            raw = json.loads(_DB_PATH.read_text(encoding="utf-8"))
            _cache = [
                MasterItem(ticker=s["ticker"], name=s["name"], exchange=s["exchange"])
                for s in raw
                if s.get("ticker") and s.get("name")
            ]
            logger.info("[Master] stock_db.json에서 %d종목 로드", len(_cache))
        except Exception as e:
            logger.warning("[Master] stock_db.json 로드 실패: %s", e)

    # 2. KIS 마스터 ZIP (운영 서버용 최신 갱신 — 실패 시 무시)
    items: list[MasterItem] = []
    for url, exchange in [(_KOSPI_URL, "KOSPI"), (_KOSDAQ_URL, "KOSDAQ")]:
        try:
            batch = await _fetch_and_parse(url, exchange)
            items.extend(batch)
            logger.info("[Master] KIS ZIP %s %d종목 갱신", exchange, len(batch))
        except Exception as e:
            logger.debug("[Master] KIS ZIP %s 스킵 (%s)", exchange, e)

    if items:
        _cache = items
        logger.info("[Master] KIS ZIP 갱신 완료 — 총 %d종목", len(_cache))

    return len(_cache)


def is_loaded() -> bool:
    return bool(_cache)


def search(query: str, limit: int = 100) -> list[MasterItem]:
    if not _cache:
        return []
    q = query.strip()
    if not q:
        return _cache[:limit]
    ql = q.lower()
    return [
        s for s in _cache
        if ql in s.ticker or ql in s.name.lower()
    ][:limit]


async def _fetch_and_parse(url: str, exchange: str) -> list[MasterItem]:
    async with httpx.AsyncClient(verify=False) as client:
        resp = await client.get(url, timeout=30, follow_redirects=True)
        resp.raise_for_status()

    with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
        raw = zf.read(zf.namelist()[0])

    items: list[MasterItem] = []
    for raw_line in raw.split(b'\n'):
        line = raw_line.rstrip(b'\r')
        if len(line) < _NAME_END:
            continue
        try:
            ticker = line[_TICKER_START:_TICKER_END].decode('cp949').strip()[:6]
            name   = line[_NAME_START:_NAME_END].decode('cp949').strip()
        except UnicodeDecodeError:
            continue
        if not ticker.isdigit() or not name:
            continue
        items.append(MasterItem(ticker=ticker, name=name, exchange=exchange))

    return items
