from dataclasses import dataclass


@dataclass(frozen=True)
class SymbolInfo:
    ticker: str
    name: str
    sub: str
    exchange: str
    category: str  # 주식 | 해외주식 | 암호화폐


SYMBOL_DB: list[SymbolInfo] = [
    # ── 코스피 대형주 ────────────────────────────────────────────────
    SymbolInfo("005930", "삼성전자",         "Samsung Electronics",    "KRX",    "주식"),
    SymbolInfo("000660", "SK하이닉스",       "SK Hynix Inc",           "KRX",    "주식"),
    SymbolInfo("005380", "현대차",           "Hyundai Motor",          "KRX",    "주식"),
    SymbolInfo("000270", "기아",             "Kia Corp",               "KRX",    "주식"),
    SymbolInfo("006400", "삼성SDI",          "Samsung SDI",            "KRX",    "주식"),
    SymbolInfo("051910", "LG화학",           "LG Chem",                "KRX",    "주식"),
    SymbolInfo("066570", "LG전자",           "LG Electronics",         "KRX",    "주식"),
    SymbolInfo("003550", "LG",               "LG Corp",                "KRX",    "주식"),
    SymbolInfo("207940", "삼성바이오로직스", "Samsung Biologics",      "KRX",    "주식"),
    SymbolInfo("068270", "셀트리온",         "Celltrion",              "KRX",    "주식"),
    SymbolInfo("005490", "POSCO홀딩스",      "POSCO Holdings",         "KRX",    "주식"),
    SymbolInfo("096770", "SK이노베이션",     "SK Innovation",          "KRX",    "주식"),
    SymbolInfo("034730", "SK",               "SK Holdings",            "KRX",    "주식"),
    SymbolInfo("017670", "SK텔레콤",         "SK Telecom",             "KRX",    "주식"),
    SymbolInfo("030200", "KT",               "KT Corp",                "KRX",    "주식"),
    SymbolInfo("015760", "한국전력",         "Korea Electric Power",   "KRX",    "주식"),
    SymbolInfo("028260", "삼성물산",         "Samsung C&T",            "KRX",    "주식"),
    SymbolInfo("012330", "현대모비스",       "Hyundai Mobis",          "KRX",    "주식"),
    SymbolInfo("105560", "KB금융",           "KB Financial Group",     "KRX",    "주식"),
    SymbolInfo("055550", "신한지주",         "Shinhan Financial",      "KRX",    "주식"),
    SymbolInfo("086790", "하나금융지주",     "Hana Financial Group",   "KRX",    "주식"),
    SymbolInfo("316140", "우리금융지주",     "Woori Financial Group",  "KRX",    "주식"),
    SymbolInfo("032830", "삼성생명",         "Samsung Life Insurance", "KRX",    "주식"),
    SymbolInfo("003490", "대한항공",         "Korean Air",             "KRX",    "주식"),
    SymbolInfo("010950", "S-Oil",            "S-Oil Corp",             "KRX",    "주식"),
    SymbolInfo("011200", "HMM",              "HMM Co Ltd",             "KRX",    "주식"),
    SymbolInfo("004020", "현대제철",         "Hyundai Steel",          "KRX",    "주식"),
    SymbolInfo("010130", "고려아연",         "Korea Zinc",             "KRX",    "주식"),
    SymbolInfo("009150", "삼성전기",         "Samsung Electro-Mech",   "KRX",    "주식"),
    SymbolInfo("018880", "한온시스템",       "Hanon Systems",          "KRX",    "주식"),
    SymbolInfo("011790", "SK케미칼",         "SK Chemicals",           "KRX",    "주식"),
    SymbolInfo("373220", "LG에너지솔루션",   "LG Energy Solution",     "KRX",    "주식"),
    # ── 두산 그룹 ────────────────────────────────────────────────────
    SymbolInfo("034020", "두산에너빌리티",   "Doosan Enerbility",      "KRX",    "주식"),
    SymbolInfo("241560", "두산밥캣",         "Doosan Bobcat",          "KRX",    "주식"),
    SymbolInfo("336260", "두산퓨얼셀",       "Doosan Fuel Cell",       "KRX",    "주식"),
    SymbolInfo("000150", "두산",             "Doosan Corp",            "KRX",    "주식"),
    # ── 2차전지 / 반도체 ─────────────────────────────────────────────
    SymbolInfo("247540", "에코프로비엠",     "EcoPro BM",              "KOSDAQ", "주식"),
    SymbolInfo("086520", "에코프로",         "EcoPro",                 "KOSDAQ", "주식"),
    SymbolInfo("112610", "씨에스윈드",       "CS Wind",                "KRX",    "주식"),
    SymbolInfo("000990", "DB하이텍",         "DB HiTek",               "KRX",    "주식"),
    # ── 코스닥 대형주 ────────────────────────────────────────────────
    SymbolInfo("035420", "네이버",            "NAVER Corp",             "KRX",    "주식"),
    SymbolInfo("035720", "카카오",           "Kakao Corp",             "KRX",    "주식"),
    SymbolInfo("323410", "카카오뱅크",       "Kakao Bank",             "KRX",    "주식"),
    SymbolInfo("259960", "크래프톤",         "Krafton",                "KRX",    "주식"),
    SymbolInfo("251270", "넷마블",           "Netmarble",              "KRX",    "주식"),
    SymbolInfo("263750", "펄어비스",         "Pearl Abyss",            "KOSDAQ", "주식"),
    SymbolInfo("293490", "카카오게임즈",     "Kakao Games",            "KOSDAQ", "주식"),
    SymbolInfo("196170", "알테오젠",         "Alteogen",               "KOSDAQ", "주식"),
    SymbolInfo("091990", "셀트리온헬스케어", "Celltrion Healthcare",   "KOSDAQ", "주식"),
    SymbolInfo("357780", "솔브레인",         "Soulbrain",              "KOSDAQ", "주식"),
    # ── 해외주식 ─────────────────────────────────────────────────────
    SymbolInfo("AAPL",  "Apple",             "Apple Inc.",             "NASDAQ", "해외주식"),
    SymbolInfo("MSFT",  "Microsoft",         "Microsoft Corp",         "NASDAQ", "해외주식"),
    SymbolInfo("NVDA",  "NVIDIA",            "NVIDIA Corp",            "NASDAQ", "해외주식"),
    SymbolInfo("TSLA",  "Tesla",             "Tesla Inc.",             "NASDAQ", "해외주식"),
    SymbolInfo("AMZN",  "Amazon",            "Amazon.com Inc.",        "NASDAQ", "해외주식"),
    SymbolInfo("GOOGL", "Alphabet",          "Alphabet Inc.",          "NASDAQ", "해외주식"),
    SymbolInfo("META",  "Meta",              "Meta Platforms Inc.",    "NASDAQ", "해외주식"),
    # ── 암호화폐 (Upbit) ─────────────────────────────────────────────
    SymbolInfo("BTC",  "Bitcoin",            "Bitcoin / KRW",          "Upbit",  "암호화폐"),
    SymbolInfo("ETH",  "Ethereum",           "Ethereum / KRW",         "Upbit",  "암호화폐"),
    SymbolInfo("XRP",  "Ripple",             "Ripple / KRW",           "Upbit",  "암호화폐"),
    SymbolInfo("SOL",  "Solana",             "Solana / KRW",           "Upbit",  "암호화폐"),
    SymbolInfo("BNB",  "BNB",               "BNB / KRW",              "Upbit",  "암호화폐"),
    SymbolInfo("DOGE", "Dogecoin",           "Dogecoin / KRW",         "Upbit",  "암호화폐"),
    SymbolInfo("ADA",  "Cardano",            "Cardano / KRW",          "Upbit",  "암호화폐"),
]


def search_symbols(query: str = "", category: str = "전체") -> list[SymbolInfo]:
    q = query.lower().strip()
    return [
        s for s in SYMBOL_DB
        if (category == "전체" or s.category == category)
        and (
            not q
            or q in s.ticker.lower()
            or q in s.name.lower()
            or q in s.sub.lower()
        )
    ]
