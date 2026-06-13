# KIS 자동매매 시스템 — 프로젝트 컨텍스트

## 세션 시작 파이프라인
**새 대화가 시작되면 반드시 아래 순서를 실행할 것:**

1. **Jira 조회** — `mcp__atlassian__searchJiraIssuesUsingJql` 으로 KAN 프로젝트 미완료 이슈 조회
   - JQL: `project = KAN AND status != 완료 ORDER BY created ASC`
   - cloudId: `3c7947ac-7881-48f5-b750-26b06c9ce78e`
2. **현황 요약 출력** — 진행 중 / 해야 할 일 이슈 목록을 표로 출력
3. **다음 작업 제안** — 우선순위 기준으로 이어할 작업 제안

> 작업 진행 상황의 Source of Truth는 Jira. CLAUDE.md에 완료 체크리스트를 쌓지 말 것.

## 규칙
- 작업 완료 시 항상 Git 커밋할 것
- 커밋 메시지는 한국어로 작성
- Jira 이슈 번호 포함할 것 (예: KAN-1)
- 작업 완료 시 해당 Jira 이슈를 "완료"로 전환할 것 (`mcp__atlassian__transitionJiraIssue`, transition id: `"41"`)
- Jira 이슈 생성/수정 시 description은 반드시 `contentFormat: "adf"` + ADF JSON 구조로 작성 (markdown 포맷은 \n이 이중 이스케이프되어 글자 그대로 노출됨)

## 프로젝트 목표
한국투자증권(KIS) OpenAPI 기반 자동매매 봇.
- 지정가 도달 시 자동 매수/매도
- RSI, 이동평균, 스캘핑 전략 자동 실행
- Flutter 모바일 앱으로 모니터링 (아이폰)
- Firebase FCM 푸시 알림 (텔레그램 대체)

## 개발 환경
- **OS**: macOS (Apple Silicon M 시리즈)
- **IDE**: IntelliJ IDEA (Flutter 플러그인 설치됨)
- **Python**: 3.9, 가상환경 `.venv/`
- **Flutter**: 3.44.1 설치됨, Xcode 26.5 설치됨
- **서버 실행**: `.venv/bin/uvicorn app.main:app --reload --reload-dir app`
  - `--reload-dir app` 필수 — 없으면 `mobile/build/` 변경에 반응해 서버가 계속 재시작됨

## 프로젝트 구조

```
trading-bot/
├── app/
│   ├── main.py                    # FastAPI 앱 진입점, lifespan 관리
│   ├── core/
│   │   ├── config.py              # .env 기반 Settings (pydantic-settings)
│   │   └── dependencies.py        # DI 싱글톤 (lru_cache)
│   ├── kis/                       # KIS API 래퍼
│   │   ├── auth.py                # OAuth 토큰 발급 + 파일 캐시 (kistoken_cache.json)
│   │   ├── client.py              # 공통 HTTP 클라이언트
│   │   ├── market.py              # 현재가 / OHLCV 조회
│   │   ├── orders.py              # 지정가/시장가 매수/매도
│   │   ├── account.py             # 잔고 조회
│   │   └── ws_client.py           # KIS WebSocket (실시간 체결가, tr_id: H0STCNT0)
│   ├── strategies/
│   │   ├── base.py                # BaseStrategy, Signal(BUY/SELL/HOLD), StrategyResult
│   │   ├── rsi.py                 # RSI 과매수/과매도
│   │   ├── moving_average.py      # 골든크로스/데드크로스
│   │   └── scalping.py            # Bollinger Band + Stochastic
│   ├── services/
│   │   ├── price_monitor.py       # 지정가 감시 백그라운드 폴링 (5초 간격)
│   │   ├── realtime.py            # WebSocket 브로드캐스트 서비스
│   │   ├── scheduler.py           # APScheduler 전략 자동 실행
│   │   └── push.py                # Firebase FCM 푸시 알림 (telegram.py 대체)
│   └── api/routes/
│       ├── market.py              # GET /api/v1/market/...
│       ├── account.py             # GET /api/v1/account/...
│       ├── orders.py              # POST /api/v1/orders/...
│       ├── strategy.py            # GET /api/v1/strategy/...
│       ├── scheduler.py           # CRUD /api/v1/scheduler/jobs
│       ├── devices.py             # POST /api/v1/devices — FCM 토큰 등록
│       └── ws.py                  # WS /ws/price/{ticker}
├── agents/                        # 멀티 에이전트 구조 (실험적)
│   ├── backend_agent.py
│   ├── frontend_agent.py
│   ├── designer_agent.py
│   └── team.py
├── mobile/                        # Flutter 앱
│   ├── lib/
│   │   ├── screens/
│   │   │   ├── home/
│   │   │   │   ├── home_screen.dart         # 왓치리스트 (Slidable + Reorderable)
│   │   │   │   ├── stock_search_screen.dart # 종목 검색 전체화면 모달
│   │   │   │   └── mini_chart_sheet.dart    # 미니차트 바텀시트 (면적 차트)
│   │   │   ├── chart/
│   │   │   │   ├── chart_screen.dart        # 캔들스틱 차트 화면 + 인터벌 선택 + 데모 폴백
│   │   │   │   └── candle_chart.dart        # Flutter CustomPainter 네이티브 캔들차트
│   │   │   ├── auto_trade/auto_trade_screen.dart
│   │   │   ├── balance/balance_screen.dart
│   │   │   ├── menu/menu_screen.dart
│   │   │   ├── auth/login_screen.dart       # Google/Apple 로그인
│   │   │   ├── onboarding/                  # 3단계 온보딩
│   │   │   └── splash_screen.dart
│   │   ├── providers/
│   │   │   ├── auth_provider.dart           # Firebase Auth 상태
│   │   │   ├── chart_provider.dart          # 선택 종목 공유 (홈↔차트)
│   │   │   ├── price_provider.dart
│   │   │   ├── balance_provider.dart
│   │   │   └── job_provider.dart
│   │   ├── services/
│   │   │   └── market_data_service.dart     # KIS/Upbit/더미 시세 라우팅
│   │   ├── core/app_colors.dart             # 디자인 토큰
│   │   └── main.dart                        # MainScaffold (IndexedStack 5탭)
│   ├── web/                                 # Flutter 웹 플랫폼
│   ├── ios/Runner/                          # GoogleService-Info.plist
│   ├── macos/Runner/                        # GoogleService-Info.plist, entitlements
│   └── firebase_options.dart
├── tests/
│   ├── test_kis_client.py         # 전략 유닛 테스트
│   ├── test_ws_client.py          # WebSocket 파싱/콜백 테스트
│   └── test_scheduler.py          # 스케줄러 잡 실행 테스트
├── .env                           # 실제 인증정보 (gitignore)
├── .env.example                   # 환경변수 템플릿
└── requirements.txt
```

## 주요 설계 결정

### KIS API
- 모의투자: `https://openapivts.koreainvestment.com:29443`
- 실거래: `https://openapi.koreainvestment.com:9443`
- WebSocket: `ws://ops.koreainvestment.com:21000` (모의/실거래 공통)
- `KIS_IS_MOCK=true/false` 환경변수로 전환
- OAuth 토큰은 `kistoken_cache.json`에 캐시 (만료 1분 전 자동 갱신)

### WebSocket (KIS → 서버)
- approval_key는 REST `/oauth2/Approval`로 별도 발급
- 실시간 체결가 tr_id: `H0STCNT0`
- 메시지 형식: `encrypt_flag|tr_id|cnt|field1^field2^...`
- PINGPONG JSON 수신 시 그대로 pong 응답
- 연결 끊기면 지수 백오프(1→2→4→...60초) 재접속

### WebSocket (서버 → Flutter 앱)
- 엔드포인트: `ws://서버주소:8000/ws/price/{ticker}`
- 구독자 0명이면 KIS WS 구독도 자동 해제

### APScheduler
- `AsyncIOScheduler` (FastAPI와 동일 이벤트 루프, Asia/Seoul 타임존)
- 잡 ID: `{ticker}_{strategy_name}` — 조합당 1개, 재등록 시 자동 교체
- `max_instances=1` — 중복 실행 방지
- 실행 이력 잡당 최근 50건 인메모리 보관
- 오류 발생 시 텔레그램 알림 후 다음 스케줄 유지

## REST API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/health` | 서버 상태 |
| GET | `/api/v1/market/price/{ticker}` | 현재가 |
| GET | `/api/v1/market/ohlcv/{ticker}` | 일봉 데이터 |
| GET | `/api/v1/account/balance` | 잔고 조회 |
| POST | `/api/v1/orders/buy/limit` | 지정가 매수 |
| POST | `/api/v1/orders/sell/limit` | 지정가 매도 |
| POST | `/api/v1/orders/buy/market` | 시장가 매수 |
| POST | `/api/v1/orders/sell/market` | 시장가 매도 |
| POST | `/api/v1/orders/alerts` | 지정가 알림 등록 |
| GET | `/api/v1/orders/alerts` | 알림 목록 |
| DELETE | `/api/v1/orders/alerts/{ticker}` | 알림 제거 |
| GET | `/api/v1/strategy/analyze/{strategy}/{ticker}` | 전략 분석 |
| GET | `/api/v1/strategy/strategies` | 전략 목록 |
| POST | `/api/v1/scheduler/jobs` | 자동 실행 잡 등록 |
| GET | `/api/v1/scheduler/jobs` | 잡 목록 |
| DELETE | `/api/v1/scheduler/jobs/{job_id}` | 잡 제거 |
| POST | `/api/v1/scheduler/jobs/{job_id}/pause` | 잡 일시정지 |
| POST | `/api/v1/scheduler/jobs/{job_id}/resume` | 잡 재개 |
| POST | `/api/v1/scheduler/jobs/{job_id}/run` | 즉시 실행 |
| GET | `/api/v1/scheduler/jobs/{job_id}/history` | 실행 이력 |
| WS | `/ws/price/{ticker}` | 실시간 체결가 |
| GET | `/api/v1/realtime/status` | WebSocket 상태 |

## 환경변수 (.env)

```
KIS_APP_KEY=...
KIS_APP_SECRET=...
KIS_ACCOUNT_NO=...              # 계좌번호 앞 8자리
KIS_ACCOUNT_PRODUCT_CODE=01
KIS_IS_MOCK=true                # true=모의투자, false=실거래

FCM_CREDENTIALS_PATH=...        # Firebase 서비스 계정 JSON 경로 (선택)
```

## 테스트 실행

```bash
.venv/bin/pytest tests/ -v
```

현재 24개 테스트 전부 통과.

## Flutter 앱 빌드 방법
- macOS: `flutter run -d macos`
- Chrome: `flutter run -d chrome`
- iOS 실기기: USB 연결 후 `flutter run`

## 네트워크 연결 (개발 시)
- 서버 URL 단일 관리: `mobile/lib/core/constants.dart`의 `kBaseUrl` / `kWsBaseUrl`
  - 모든 화면이 이 상수를 참조 (chart_screen, market_data_service 포함)
- 아이폰 ↔ 맥 연결 옵션 (KAN-15):
  - **Tailscale (권장)**: 맥+아이폰에 설치 시 고정 IP(`100.x.x.x`) 부여, 터널 불필요
  - **localhost.run 터널**: `ssh -R 80:localhost:8000 nokey@localhost.run` — URL이 매 연결마다 바뀜
- AP isolation 문제로 로컬 IP 직접 연결 불가 → 터널 또는 Tailscale 필수
- 데모 데이터 폴백: 백엔드 없어도 차트 표시됨 (200개 더미 캔들)

## Flutter 실기기 빌드 주의사항
- **debug 빌드** (`flutter run`): `flutter run` 세션 연결 중에만 동작. 아이콘 탭으로 독립 실행 불가.
- **release 빌드** (`flutter run --release`): 독립 실행 가능. 실제 테스트 시 사용.
- 실기기 flutter run 실행 디렉토리: `mobile/` (pubspec.yaml 위치)

## 캔들차트 (candle_chart.dart) 주요 기능
- Flutter CustomPainter 기반 네이티브 구현 (WebView/TradingView 미사용)
- 롱프레스 → 점선 크로스헤어 표시, 손 뗀 후 유지, 탭으로 해제
- 크로스헤어 활성 시 어디서든 꾹 누르면 상대 위치로 이동
- 슬라이드(패닝) 시 크로스헤어 자동 해제 + 차트 스크롤
- 오른쪽 가격축 드래그 → 세로 줌 (exp 스케일)
- 차트 영역 핀치 → 가로 줌 (visibleCount 조절)
- 오른쪽 슬라이드 → 과거 데이터, 왼쪽 슬라이드 → 최신 데이터
