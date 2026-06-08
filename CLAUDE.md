# KIS 자동매매 시스템 — 프로젝트 컨텍스트

## 규칙
- 작업 완료 시 항상 Git 커밋할 것
- 커밋 메시지는 한국어로 작성
- Jira 이슈 번호 포함할 것 (예: KAN-1)
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
- **서버 실행**: `.venv/bin/uvicorn app.main:app --reload`

## 현재 진행 상태

### 완료
- [x] 1단계: FastAPI 백엔드 + KIS 모의투자 API 연동
- [x] 2단계: KIS WebSocket 실시간 호가 수신
- [x] 3단계: APScheduler 전략 자동 실행
- [x] 4단계: Flutter 모바일 앱 초기 구조 (home/balance/orders/jobs 화면)
- [x] Firebase FCM 푸시 알림 백엔드 (telegram.py 제거, push.py 추가)
- [x] Google/Apple 로그인 화면 구현 (AuthProvider, LoginScreen, Firebase Auth 연동)
- [x] Firebase 프로젝트 설정 (momentum-6ec82, Bundle ID: com.momentumtrade.momentum)
- [x] macOS 빌드 환경 구성 (entitlements, URL scheme, DEVELOPMENT_TEAM)
- [x] 로그인 화면 macOS에서 UI 정상 확인

### 다음에 이어서 할 일
- [ ] KAN-10: iOS 실기기 Google/Apple 로그인 실제 동작 테스트 (USB 케이블 필요)
- [ ] KAN-11: Flutter UI 완성 (Figma 디자인 연동, Figma MCP 한도 풀리면)
- [ ] KAN-12: 클라우드 배포 (24/7 운영, 서버 선택 필요)

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
├── mobile/                        # Flutter 앱 (생성됨)
│   ├── lib/
│   │   ├── screens/               # home, balance, orders, jobs, auth/login
│   │   ├── providers/             # price, balance, job, auth
│   │   └── models/
│   ├── ios/Runner/                # GoogleService-Info.plist 포함
│   ├── macos/Runner/              # GoogleService-Info.plist, entitlements, Info.plist
│   └── firebase_options.dart      # flutterfire configure 자동 생성
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

## Flutter 앱 현황

### 완성된 것
- 화면: home, balance, orders, jobs, login
- 로그인: Google/Apple 버튼 UI + AuthProvider + Firebase Auth 연동
- Firebase 프로젝트: `momentum-6ec82` (yeoingyu26@gmail.com)
- Bundle ID: `com.momentumtrade.momentum` (iOS/Android/macOS 통일)
- macOS 로그인 화면 UI 정상 확인 (스크린샷 완료)

### 남은 것
- iOS 실기기에서 Google/Apple 로그인 실제 동작 테스트 (USB 필요)
- iOS 시뮬레이터 런타임 미설치 (Xcode 26.5 — 별도 다운로드 필요)

### 빌드 방법
- macOS: `flutter run -d macos` (로그인 UI 확인용, 실제 로그인은 키체인 제한)
- iOS 실기기: USB 연결 후 `flutter run` (실제 로그인 동작)
- Chrome: `flutter run -d chrome`
