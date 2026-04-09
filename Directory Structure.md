````markdown
GPT2team/
│
├── CHEAT_REMOVAL_GUIDE.md          # 출시 전 치트/어드민 API 제거 가이드
├── JSON_SCRIPT_GUIDE.md            # 스토리 JSON 스크립트 작성 가이드
│
├── backend/
│   └── app/
│       ├── main.py                 # FastAPI 앱 진입점
│       ├── config.py               # 게임 상수 (AP, 페널티, 선물비용 등)
│       ├── models.py               # DB 모델 (User, HeroineProgress, ViewedZone)
│       ├── database.py             # SQLite 연결 설정
│       ├── routers.py              # API 엔드포인트 정의
│       ├── services.py             # 게임 로직 서비스 (페널티, 리셋)
│       ├── dependencies.py         # JWT 인증 미들웨어
│       ├── requirements.txt        # Python 의존성
│       └── data/
│           └── story_config.json   # 히로인별 스토리 스케줄
│
└── frontend/
    ├── lib/
    │   ├── main.dart               # Flutter 앱 진입점
    │   ├── core/
    │   │   ├── api_client.dart     # Dio HTTP 클라이언트 (JWT 자동 삽입)
    │   │   ├── constants.dart      # API URL 상수
    │   │   └── theme.dart          # 앱 테마
    │   ├── models/
    │   │   ├── user_model.dart     # 유저 데이터 모델
    │   │   └── heroine_model.dart  # 히로인 데이터 모델
    │   ├── providers/
    │   │   ├── auth_provider.dart  # 인증 상태 관리 (Riverpod)
    │   │   └── game_provider.dart  # 게임 상태 관리 (Riverpod)
    │   ├── screens/
    │   │   ├── auth/
    │   │   │   └── title_screen.dart       # 로그인/스플래시 화면
    │   │   ├── lobby/
    │   │   │   ├── lobby_screen.dart       # 메인 허브 (AP, 돈, 시간대)
    │   │   │   └── minigame_screen.dart    # 미니게임 (돈 획득)
    │   │   └── story/
    │   │       └── story_screen.dart       # 스토리 플레이어
    │   └── widgets/
    │       ├── custom_button.dart          # 공통 버튼 위젯
    │       └── story_dialog.dart           # 스토리 대화 위젯
    │
    ├── assets/
    │   ├── images/
    │   │   └── bg/
    │   │       ├── lobby_morning.jpg       # 로비 배경 (아침)
    │   │       ├── lobby_afternoon.jpg     # 로비 배경 (오후)
    │   │       ├── lobby_dawn.jpg          # 로비 배경 (저녁)
    │   │       └── lobby_night.jpg         # 로비 배경 (밤)
    │   └── scripts/
    │       ├── intro1/
    │       │   └── intro_1_prologue.json   # 공통 프롤로그
    │       └── intro2/
    │           └── 코토리/
    │               ├── day1_낮_코토리.json
    │               ├── day2_낮_코토리.json
    │               └── ... (day3~day8)
    │
    ├── android/                    # Android 빌드 설정
    ├── ios/                        # iOS 빌드 설정
    ├── macos/                      # macOS 빌드 설정
    ├── linux/                      # Linux 빌드 설정
    ├── pubspec.yaml                # Flutter 의존성
    └── analysis_options.yaml       # Dart 린트 규칙
