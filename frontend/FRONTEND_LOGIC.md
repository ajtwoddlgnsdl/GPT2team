# 📱 프론트엔드 동작 로직 및 API 연동 명세서

본 문서는 `lib` 폴더에 구현된 Flutter 프론트엔드 클라이언트의 핵심 작동 시나리오와 상태 변화, API 통신 과정을 정리한 문서입니다.

## 📂 목차
1. 앱 실행 및 자동 로그인 시나리오 (TitleScreen)
2. 신규 유저(게스트) 로그인 시나리오 (TitleScreen)
3. 개발자 치트 모드 시나리오 (TitleScreen)
4. 로비 화면 및 서버 시간 동기화 (LobbyScreen)
5. 스토리 진행 및 완료 시나리오 (StoryScreen)

---

## 1. 앱 실행 및 자동 로그인 시나리오 (`TitleScreen`)
앱을 켜고 기존 유저 정보가 있을 때, 백그라운드에서 로그인을 갱신하고 게임 시작을 대기하는 시나리오입니다.

* **초기 진입점:** `main.dart` -> `MyApp` -> `TitleScreen`
* **초기 상태:** 화면에 로딩 스피너 표시 (`_state = TitleState.loading`)

### 🔄 동작 흐름
1. `initState()` -> `_checkAutoLogin()` 호출
2. 로컬 스토리지(`ApiClient().storage`)에서 `user_id`와 `access_token` 존재 여부 확인
3. **[API 호출] 자동 로그인**
   * **Endpoint:** `POST /login`
   * **Query Parameters:**
     * `user_id` (String): 로컬에 저장된 유저 고유 ID
4. 성공 시 새로운 `access_token`을 로컬 스토리지에 덮어쓰기
5. 화면 상태를 `TitleState.readyToStart`로 변경 ➡️ **"Touch to Start" UI 노출**
6. 화면 터치 시 `_checkStoryStatus()` 함수 호출 ➡️ *(다음 스토리 또는 로비로 이동, 2번 시나리오 하단 참조)*

---

## 2. 신규 유저(게스트) 로그인 시나리오 (`TitleScreen`)
앱 최초 실행으로 로컬에 유저 정보가 없거나, 자동 로그인이 실패했을 경우 게스트 계정을 발급받는 시나리오입니다.

### 🔄 동작 흐름
1. `_checkAutoLogin()` 실패 또는 정보 없음 -> 상태를 `TitleState.needGuestLogin`로 변경 ➡️ **"게스트로 시작하기" 버튼 노출**
2. 사용자가 버튼 클릭 시 `_guestLogin()` 함수 실행
3. **[API 호출] 게스트 로그인**
   * **Endpoint:** `POST /auth/guest-login`
   * **Parameters:** 없음
   * **Response:** `access_token` (String), `user_id` (String)
4. 발급받은 토큰과 ID를 로컬 스토리지에 저장
5. 성공 즉시 "Touch to Start" 대기 없이 `_checkStoryStatus()` 자동 호출

### 🔀 `_checkStoryStatus()` 라우팅 로직
로그인(자동/게스트) 직후, 현재 시간대에 봐야 할 스토리가 있는지 서버에 묻고 화면을 전환합니다.

1. **[API 호출] 스토리 상태 체크**
   * **Endpoint:** `GET /check-story`
   * **Parameters:** 없음 (헤더에 access_token 포함)
   * **Response:** `auto_play_story` 객체 (`is_available`, `story_id`, `story_ticket`, `heroine_name`)
2. **분기 처리:**
   * `is_available == true`: `Navigator.pushReplacement` ➡️ **StoryScreen**으로 이동 (storyId, ticket 전달)
   * `is_available == false`: `Navigator.pushReplacement` ➡️ **LobbyScreen**으로 이동

---

## 3. 🛠️ (참고) 개발자 치트 모드 시나리오 (`TitleScreen`)
※ 정식 출시 전 제거되어야 하는 개발자 디버그 패널 작동 로직입니다.

1. 우측 상단 벌레 아이콘 클릭 -> `_showAdminPanel()` 다이얼로그 노출
2. 어드민 키, 오프라인 일수, 시간 조작 입력 후 '치트 적용 및 시작' 클릭
3. **[API 호출] 치트 로그인 (오프라인 일수 조작)**
   * **Endpoint:** `POST /admin/login`
   * **Headers:** `admin-key` (String)
   * **Query Parameters:**
     * `user_id` (String): 로컬 스토리지의 유저 ID
     * `cheat_offline_days` (int): 텍스트 필드로 입력받은 숫자
4. **[API 호출] 치트 스토리 체크 (시간 조작)**
   * **Endpoint:** `GET /admin/check-story`
   * **Headers:** `admin-key` (String)
   * **Query Parameters:**
     * `cheat_hour` (int): 텍스트 필드로 입력받은 0~23 사이의 시간
5. 일반 로직과 동일하게 결과에 따라 `StoryScreen` 또는 `LobbyScreen`으로 즉시 진입

---

## 4. 로비 화면 및 서버 시간 동기화 (`LobbyScreen`)
현재 유저의 재화 상태를 보여주고, 시간대에 따라 배경과 버튼이 바뀌는 메인 허브 화면입니다.

* **초기 진입점:** `LobbyScreen` (`_isLoading = true` 상태로 시작)

### 🔄 동작 흐름 및 시간 보정 (Time Offset) 로직
1. `initState()` -> `_loadLobbyData()` 실행
2. **[API 호출] 서버 시간 동기화**
   * **Endpoint:** `GET /server-time`
   * **Response:** `timestamp` (String, ISO-8601 포맷)
   * **내부 로직:** API 요청/응답 왕복 시간을 계산하여 지연시간(latency)을 보정한 뒤, 기기 시간과 서버 시간의 격차(`_timeOffset`: Duration)를 정밀하게 계산 및 저장.
3. **[API 호출] 유저 상태(재화) 로드**
   * **Endpoint:** `GET /user/status`
   * **Response:** `username` (String), `ap` (int), `money` (int)
4. 데이터 로드 완료 후 `_isLoading = false` 처리 및 UI 렌더링. 시간에 따라 배경(`_getBackgroundImage`) 및 액션 버튼(`_buildDynamicButtons`) 동적 생성.
5. **백그라운드 타이머 시작 (`_startTimeMonitor`)**
   * 10초마다 `기기 현재시간 + _timeOffset`을 계산하여 현재 서버 시간을 유추.
   * 새벽/아침/낮/밤 경계선이나 자정(날짜 변경)을 넘어가면 `_handleTimeBoundaryCrossed()` 이벤트 발동.

### 🕒 시간 경계선 교차 시 처리 로직 (`_handleTimeBoundaryCrossed`)
1. **[API 호출] 시간 더블 체크**
   * **Endpoint:** `POST /verify-time`
   * **Body Data:** `{"client_estimated_hour": int}` (유추된 시간)
2. 날짜가 바뀌었을 경우 (자정 경과 시)
   * `POST /login` 재호출 및 `GET /user/status`로 일일 AP/돈 초기화 내역 갱신
3. 새로운 시간대에 스토리가 열렸는지 `GET /check-story` 호출.
   * 스토리가 있으면 `StoryScreen`으로 납치(이동), 없으면 로비 배경/버튼만 리렌더링.

---

## 5. 스토리 진행 및 완료 시나리오 (`StoryScreen`)
대본(JSON)을 파싱하여 대화와 연출을 보여주고, 선택지 입력 및 스토리 완료 처리를 수행합니다.

* **초기 진입점:** `StoryScreen` (이전 화면에서 전달받은 `storyId`, `storyTicket` 변수 보유)

### 🔄 동작 흐름
1. `initState()` -> `_loadPlayerName()`, `_loadStoryScript()`
2. `storyId` 문자열 접두사(intro, main, ending 등)를 분석하여 로컬 자산 경로(`assets/scripts/...`)에서 JSON 대본 파일 로드 및 파싱 (`_scriptLines` List에 저장).
3. 화면 터치 시 `_nextStory()` -> `_advanceLine()`을 통해 `_currentIndex`를 증가시키며 배경, 캐릭터 스탠딩, 화자, 텍스트 업데이트. (이름 변수 `{name}`은 실제 유저 이름으로 Replace 처리)

### 🌟 특수 액션 처리 (JSON 파싱 로직)
* **닉네임 입력 액션 (`"action": "input_nickname"`)**
  * 화면 터치 진행을 멈추고 `_showNameInputDialog()` 다이얼로그 팝업.
  * **[API 호출] 닉네임 설정**
    * **Endpoint:** `POST /update-nickname`
    * **Body Data:** `{"username": String (입력값)}`
  * API 성공 시 로컬 스토리지 갱신 후, 다음 대사로 자동 진행.
* **선택지 액션 (`"action": "choice"`)**
  * 대화를 멈추고 `_currentChoices` 버튼들을 화면에 렌더링 (`_isChoiceMode = true`).
  * 유저 선택 시 `_onChoiceSelected()` 실행.
  * 선택지에 `bonus_score`가 있다면 `_earnedBonusScore` 변수에 정수(int) 저장.
  * 선택지에 `next_lines` 배열이 있다면 현재 남은 대본 스크립트 사이에 끼워넣기(`insertAll`) 수행.

### 🏁 스토리 완료 및 서버 저장
대본을 끝까지 다 읽었을 때 실행됩니다.

1. `_completeStory()` 함수 실행.
2. 획득한 `_earnedBonusScore`가 0보다 크면, 프론트엔드에서 직접 2시간 만료의 **JWT 토큰**으로 암호화 생성 (`dart_jsonwebtoken` 패키지 및 `.env`의 `JWT_SECRET_KEY` 사용).
3. **[API 호출] 스토리 클리어**
   * **Endpoint:** `POST /complete-story`
   * **Body Data:**
     * `story_ticket` (String): 진입 시 서버로부터 받았던 티켓
     * `bonus_token` (String, Optional): 호감도 점수가 암호화된 JWT 토큰
4. 통신 성공 시 `Navigator.pushReplacement`를 통해 `LobbyScreen`으로 복귀. (스토리는 다시 진입할 수 없음)