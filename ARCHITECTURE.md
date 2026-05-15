# 🏗️ Project Heroine - 기술 스택 및 아키텍처 명세서

본 문서는 `Project Heroine`의 전반적인 기술 스택과 프론트엔드/백엔드 아키텍처, 핵심 시스템 동작 원리를 정리한 문서입니다.

---

## 🛠️ 1. 기술 스택 (Tech Stack)

### 📱 Frontend (Client)
- **Framework:** Flutter / Dart
- **Network:** Dio (API 통신 및 인터셉터 처리)
- **Storage:** flutter_secure_storage (유저 식별자, JWT 토큰 저장)
- **Security:** dart_jsonwebtoken (클라이언트 측 단기 토큰 서명), flutter_dotenv (환경변수 관리)
- **UI/UX:** CustomPainter (날씨/시간대별 파티클 애니메이션), 비주얼 노벨 스타일 대화창

### ⚙️ Backend (Server)
- **Framework:** FastAPI / Python
- **Database/ORM:** SQLAlchemy (RDBMS 연동)
- **Security/Auth:** PyJWT (Stateless 인증 및 스토리 티켓 검증)
- **Architecture:** Layered Architecture (Routers, Services, Models 분리)

---

## 📐 2. 시스템 아키텍처 및 핵심 로직

### 🕒 A. 정밀한 서버 시간 동기화 (Time Synchronization)
모바일 기기의 로컬 시간을 조작하는 어뷰징을 방지하고, 시간대별 이벤트를 정확하게 처리하기 위해 **Offset 기반 시간 유추 시스템**을 사용합니다.

1. **Latency 보정:** 로비(`LobbyScreen`) 진입 시 `GET /server-time`을 호출하여 API 왕복 지연 시간(Latency)의 절반을 계산해 오프셋(`_timeOffset`)에 반영합니다.
2. **백그라운드 유추:** 매초 서버에 요청을 보내지 않고, 기기 시간(`DateTime.now()`)에 보정된 `_timeOffset`을 더해 클라이언트에서 서버 시간을 유추합니다.
3. **경계선 검증:** 자정이나 시간대(아침/낮/밤)가 변경되는 순간에만 `POST /verify-time` API를 호출해 서버와 교차 검증(Double Check)을 수행합니다. 자정 경과 시 AP/재화 초기화 로직을 자동으로 트리거합니다.

### 📖 B. JSON 기반 스토리 렌더링 엔진 (Story Engine)
비주얼 노벨 형태의 게임 플레이를 제공하기 위해, 프론트엔드에 내장된 스크립트 해석기를 사용합니다.

1. **동적 파싱:** `StoryScreen`에서 백엔드가 지시한 `story_id`를 기반으로 로컬 `assets/scripts/...`의 JSON 파일을 불러옵니다.
2. **상호작용 연출:** 
   - **텍스트/배경/캐릭터:** 대본의 상태에 따라 배경과 캐릭터 이미지를 업데이트합니다.
   - **닉네임 치환:** `{name}` 포맷을 유저가 설정한 이름으로 실시간 치환합니다.
   - **동적 선택지:** `"action": "choice"`가 등장하면 선택지 UI를 띄우고, 선택 결과에 따라 `"next_lines"`를 현재 스크립트 배열에 동적으로 삽입(`List.insertAll`)하여 분기를 처리합니다.

### 🔒 C. JWT 기반 인증 및 스토리 티켓 시스템
상태(State)를 서버 세션에 저장하지 않는 완전한 Stateless 구조를 채택했습니다.

1. **액세스 토큰 (Access Token):** 로그인 시 발급되며 2시간의 유효기간을 가집니다. `ApiClient` 인터셉터를 통해 모든 요청 헤더에 자동으로 주입됩니다.
2. **스토리 티켓 (Story Ticket):** 
   - 유저가 특정 시간대에 진입하면, 서버는 해당 시간대(Zone)와 캐릭터 정보를 담아 `jwt.encode`된 1회용 스토리 티켓을 발급합니다.
   - 스토리를 끝까지 읽으면 이 티켓을 다시 서버(`/complete-story`)로 제출하여 클리어 검증을 받습니다.
3. **클라이언트 서명 보너스 (Client-side Bonus Token):** 
   - 유저가 올바른 선택지를 골라 추가 호감도를 얻었을 경우, 프론트엔드에서 직접 `.env`의 Secret Key를 이용해 호감도 보너스가 담긴 임시 JWT를 생성합니다.
   - 이를 완료 API에 함께 실어 보내 데이터 위변조를 방지하면서도 서버 연산을 줄였습니다.
   - 이 토큰은 클라이언트 기기 시간 오차로 인한 만료 문제를 방지하기 위해 별도의 만료 시간(`expiresIn`)을 가지지 않습니다. 대신, `story_ticket`의 만료 시간에 의존하여 유효성이 검증됩니다.

### 🎮 D. 게임 경제 및 상태 관리 (Game Economy & State)
- **재화 (AP / Money):** 행동력(AP)을 소모하여 미니게임을 플레이하고, 얻은 재화(Money)로 선물을 구매해 호감도를 올립니다.
- **진척도 (Heroine Progress):** 캐릭터별로 호감도, 진행 일차(`current_day`), 해당 일차에 본 시간대(`viewed_zones`)를 개별 관리합니다.
- **게임 상태 (GameState):** `INTRO_1`(프롤로그) -> `INTRO_2`(공통 튜토리얼) -> `MAIN`(본편) -> `END`(엔딩) 로 상태 머신이 관리됩니다.

---

## 📁 3. 주요 디렉토리 구조 (추론)

```text
c:\dev\GPT2team\
├── backend/                        # FastAPI 백엔드
│   └── app/
│       ├── config.py               # 설정 및 스토리/히로인 메타데이터 (STORY_CONFIG 등)
│       ├── dependencies.py         # DB 세션 및 현재 유저 종속성 (get_db, get_current_user)
│       ├── models.py               # SQLAlchemy 데이터베이스 모델 
│       ├── routers.py              # API 엔드포인트 (Auth, Story, GameLogic 등)
│       └── services.py             # 비즈니스 로직 (페널티 계산, 리셋 등)
│
└── frontend/                       # Flutter 클라이언트
    ├── assets/
    │   ├── images/                 # 배경(bg) 및 캐릭터 스탠딩(character) 이미지
    │   └── scripts/                # JSON 기반 스토리 대본 파일
    ├── lib/
    │   ├── core/
    │   │   ├── api_client.dart     # Dio 싱글톤 인스턴스 (인터셉터, 스토리지 포함)
    │   │   └── constants.dart      # 플랫폼 분기 API Base URL, JWT Secret 등 환경변수
    │   ├── screens/
    │   │   ├── auth/
    │   │   │   └── title_screen.dart # 로그인, 게스트 계정 생성, 파티클 배경
    │   │   ├── lobby/
    │   │   │   └── lobby_screen.dart # 로비 UI, 서버 시간 동기화 백그라운드 모니터링
    │   │   └── story/
    │   │       └── story_screen.dart # JSON 스크립트 파싱, 비주얼 노벨 플레이어 구동
    │   └── main.dart               # 앱 진입점 (dotenv 초기화 및 테마 설정)
    ├── .env                        # 환경 변수 (JWT_SECRET_KEY 보관)
    └── FRONTEND_LOGIC.md           # 프론트엔드 핵심 로직 상세 설명서
```

---

## 🛡️ 4. 예외 및 방어 로직 (Defensive Programming)
- **엄격한 스토리 티켓 검증:** 프롤로그(튜토리얼)를 포함한 모든 스토리 진입 및 완료 시 서버에서 발급한 JWT 스토리 티켓을 엄격하게 검증하여 비정상적인(오프라인) 접근을 원천 차단합니다.
- **화면 갇힘 방지 (Anti-Lock):** 스토리 완료 통신 시 에러(티켓 만료, 중복 클리어 등)가 반환되면, 유저를 영원히 로딩 창에 가두지 않고 에러 메시지와 함께 강제로 `LobbyScreen`으로 스무스하게 갈아끼우도록(`pushReplacement`) 설계되었습니다.
- **관리자 패널:** 화면 구석의 버그 아이콘 롱프레스를 통해 어드민 키를 입력하면 시간과 오프라인 일수를 조작하여 즉각적인 테스트가 가능한 치트 기능이 내장되어 있습니다.