"""
KIS 해외주식 마스터 로더

서버 시작 시 NASDAQ/NYSE/AMEX 마스터 파일을 다운로드하여
ticker → (name, exchange_code) 매핑 테이블을 구성합니다.
이후 임의의 US 종목 코드를 검색하거나 거래소 코드를 조회할 수 있습니다.

마스터 파일 URL:
  https://new.real.download.dws.or.kr/common/master/nasdaqmaster.mst.zip
  https://new.real.download.dws.or.kr/common/master/nysemaster.mst.zip
  https://new.real.download.dws.or.kr/common/master/amexmaster.mst.zip

파일 형식 (고정 너비):
  bytes  0~ 3  : EXCD (거래소코드 4자)
  bytes  4~15  : SYMB (티커 12자, 우측 공백 패딩)
  bytes 16~65  : SYMB_NAME (영문명 50자, 우측 공백 패딩)
  이후 필드는 파싱 불필요
"""

import io
import logging
import zipfile
from dataclasses import dataclass

import httpx

from app.data.symbols import US_EXCHANGE   # 기존 하드코딩 딕셔너리 (fallback)

logger = logging.getLogger(__name__)

_MASTER_URLS: list[tuple[str, str]] = [
    ("https://new.real.download.dws.or.kr/common/master/nasdaqmaster.mst.zip", "NASD"),
    ("https://new.real.download.dws.or.kr/common/master/nysemaster.mst.zip",   "NYSE"),
    ("https://new.real.download.dws.or.kr/common/master/amexmaster.mst.zip",   "AMEX"),
]


@dataclass(frozen=True)
class USMasterItem:
    ticker: str
    name:   str
    exchange: str   # NASD | NYSE | AMEX


# ticker → USMasterItem
_cache: dict[str, USMasterItem] = {}


async def load_master() -> int:
    """서버 시작 시 호출 — NASDAQ/NYSE/AMEX 마스터 파일 다운로드 후 캐시 구성."""
    global _cache
    items: dict[str, USMasterItem] = {}

    for url, exchange in _MASTER_URLS:
        try:
            batch = await _fetch_and_parse(url, exchange)
            for it in batch:
                items[it.ticker] = it
            logger.info("[USMaster] %s %d종목 로드", exchange, len(batch))
        except Exception as e:
            logger.warning("[USMaster] %s 다운로드 실패 — 하드코딩 폴백 사용 (%s)", exchange, e)

    if items:
        _cache = items
        logger.info("[USMaster] 해외주식 마스터 총 %d종목", len(_cache))
    else:
        # 다운로드 실패 시 기존 하드코딩 목록으로 폴백
        logger.warning("[USMaster] 마스터 파일 전체 실패 — symbols.py 하드코딩 목록 사용")

    return len(_cache)


def is_loaded() -> bool:
    return bool(_cache)


def lookup_exchange(ticker: str) -> str:
    """ticker → KIS 거래소 코드 반환.
    1) 마스터 캐시 우선
    2) 하드코딩 딕셔너리 (US_EXCHANGE)
    3) 기본값 'NASD'
    """
    t = ticker.upper()
    if t in _cache:
        return _cache[t].exchange
    return US_EXCHANGE.get(t, "NASD")


def lookup_name(ticker: str) -> str:
    """마스터에서 종목명 반환. 없으면 ticker 그대로."""
    item = _cache.get(ticker.upper())
    return item.name if item else ticker


def search(query: str, limit: int = 50) -> list[USMasterItem]:
    """ticker 또는 이름으로 검색 (마스터 로드 전에는 빈 리스트 반환)."""
    if not _cache:
        return []
    q = query.strip().upper()
    if not q:
        return list(_cache.values())[:limit]
    result = [
        it for it in _cache.values()
        if q in it.ticker or q in it.name.upper()
    ]
    return result[:limit]


async def _fetch_and_parse(url: str, exchange: str) -> list[USMasterItem]:
    async with httpx.AsyncClient(verify=False) as client:
        resp = await client.get(url, timeout=30, follow_redirects=True)
        resp.raise_for_status()

    raw_bytes = resp.content

    # ZIP 여부 확인
    if url.endswith(".zip") or raw_bytes[:2] == b'PK':
        with zipfile.ZipFile(io.BytesIO(raw_bytes)) as zf:
            filename = zf.namelist()[0]
            raw_bytes = zf.read(filename)

    return _parse_mst(raw_bytes, exchange)


def _parse_mst(data: bytes, default_exchange: str) -> list[USMasterItem]:
    """KIS 해외주식 마스터 파일 파서.

    KIS 마스터 파일 형식 (고정 너비, ASCII):
      col  0~ 3 : EXCD (4자)
      col  4~15 : SYMB (12자, 우측 공백 패딩)
      col 16~65 : SYMB_NAME (50자, 우측 공백 패딩)
    """
    items: list[USMasterItem] = []
    seen: set[str] = set()

    for raw_line in data.split(b'\n'):
        line = raw_line.rstrip(b'\r\x00')
        if len(line) < 20:
            continue
        try:
            # ASCII 또는 Latin-1 디코딩 (해외주식 마스터는 영문만)
            text = line.decode('ascii', errors='ignore')
        except Exception:
            continue

        # 전략 1: 고정 너비
        excd  = text[0:4].strip()  or default_exchange
        symb  = text[4:16].strip()
        name  = text[16:66].strip() if len(text) >= 66 else text[16:].strip()

        # 유효성 검사 (SYMB는 알파벳+점 조합)
        if not symb or not symb.replace('.', '').isalpha():
            # 전략 2: 탭/공백 구분자
            parts = text.split()
            if len(parts) >= 2 and parts[0].replace('.', '').isalpha():
                symb  = parts[0]
                name  = ' '.join(parts[1:4])   # 이름은 앞 3토큰
                excd  = default_exchange
            else:
                continue

        if not name:
            name = symb
        excd = excd if excd in ("NASD", "NYSE", "AMEX") else default_exchange

        if symb not in seen:
            seen.add(symb)
            items.append(USMasterItem(ticker=symb, name=name, exchange=excd))

    return items
