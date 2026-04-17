# 📱 프론트엔드 동작 로직 및 API 연동 명세서

본 문서는 Flutter 프론트엔드 클라이언트의 핵심 동작 시나리오, 상태 변화, API 통신 과정을 코드 레벨에서 상세히 기술한 문서입니다. 코드 리뷰 및 신규 기능 개발 시 참고 자료로 활용될 수 있습니다.

## 📂 목차
1. 앱 실행 및 자동 로그인 시나리오 (TitleScreen)
2. 신규 유저(게스트) 로그인 시나리오 (TitleScreen)
3. (참고) 개발자 치트 모드 시나리오 (TitleScreen)
4. 로비 화면 및 서버 시간 동기화 (LobbyScreen)
5. 스토리 진행 및 완료 시나리오 (StoryScreen)

---

## 1. 앱 실행 및 자동 로그인 시나리오 (`TitleScreen`)
앱 실행 시 로컬에 저장된 유저 정보로 자동 로그인을 시도하고, 성공 시 게임 시작 가능 상태로 전환하는 과정입니다.

*   **핵심 파일:** `frontend/lib/screens/auth/title_screen.dart`
*   **초기 상태:** `_state = TitleState.loading` (로딩 인디케이터 표시)

### 🔄 상세 동작 흐름
1.  **`_TitleScreenState.initState()`**:
    *   UI 애니메이션 컨트롤러들(`_floatCtrl`, `_blinkCtrl` 등)과 시계 타이머(`_clockTimer`)를 초기화합니다.
    *   `_checkAutoLogin()` 함수를 즉시 호출하여 로그인 절차를 시작합니다.
2.  **`_checkAutoLogin()`**:
    *   `ApiClient().storage` (`FlutterSecureStorage`)를 통해 'user_id'와 'access_token'의 존재 여부를 확인합니다.
    *   토큰이 존재할 경우, `POST /login` API를 호출하여 토큰을 갱신합니다.
    *   **성공 시 (HTTP 200 & `status: 'success'`)**:
        *   응답으로 받은 새로운 `access_token`을 로컬 스토리지에 덮어씁니다.
        *   `setState()`를 통해 `_state`를 `TitleState.readyToStart`로 변경합니다.
    *   **실패 시 (토큰이 없거나 API 에러 발생)**:
        *   `catch` 블록에서 에러를 로깅하고, `setState()`를 통해 `_state`를 `TitleState.needLogin`으로 변경하여 게스트 로그인 플로우로 유도합니다.
3.  **UI 상호작용**:
    *   `_state`가 `TitleState.readyToStart`가 되면 "S T A R T" 버튼 등 UI가 활성화됩니다.
    *   유저가 "S T A R T" 버튼을 탭하면 `_showLoginDialog()`가 호출됩니다.
4.  **`_showLoginDialog()`**:
    *   함수 진입 시 `if (_state == TitleState.readyToStart)` 조건을 가장 먼저 확인합니다.
    *   조건이 참이므로, 로그인 다이얼로그를 띄우지 않고 즉시 `_checkStoryStatus()`를 호출하여 다음 단계로 넘어갑니다.

### 🔍 주요 함수 분석: `_checkStoryStatus()`
자동 로그인에 성공한 기존 유저가 시작할 때, 현재 봐야 할 스토리가 있는지 서버에 확인하고 화면을 전환합니다.

1.  `_state`를 `TitleState.loading`으로 변경하여 로딩 인디케이터를 다시 표시합니다.
2.  `GET /check-story` API를 호출합니다. (헤더에 현재 `access_token`이 `ApiClient` 인터셉터를 통해 자동으로 포함됩니다.)
3.  **응답 분기 처리**:
    *   `auto_play_story.is_available == true`: 현재 시간대에 봐야 할 스토리가 존재합니다.
        *   `Navigator.pushReplacement`를 사용해 `StoryScreen`으로 화면을 전환하며, `storyId`, `storyTicket`, `heroineName`을 파라미터로 전달합니다.
    *   `auto_play_story.is_available == false`: 현재 볼 스토리가 없습니다.
        *   `Navigator.pushReplacement`를 사용해 `LobbyScreen`으로 화면을 전환합니다.
4.  **에러 처리**: API 호출 실패 시 `_state`를 `TitleState.readyToStart`로 되돌려 유저가 재시도할 수 있도록 합니다.

### ⭐ 코드 리뷰 포인트
*   **상태 분리**: `TitleState` enum (`loading`, `needLogin`, `readyToStart`)을 사용하여 UI와 로직의 상태를 명확하게 분리한 점이 코드 가독성과 유지보수성을 높입니다.
*   **화면 전환**: `pushReplacement`를 사용하여 뒤로가기 스택이 쌓이지 않도록 처리한 것은, 로그인/스토리 진입과 같이 단방향으로 진행되는 플로우에 매우 적합한 방식입니다.

---

## 2. 신규 유저(게스트) 로그인 시나리오 (`TitleScreen`)
로컬 정보가 없는 신규 유저가 게스트로 계정을 생성하고, 스토리 체크를 거쳐 프롤로그 스토리를 진행하는 과정입니다.

*   **핵심 파일:** `frontend/lib/screens/auth/title_screen.dart`

### 🔄 상세 동작 흐름
1.  `_checkAutoLogin()` 실패 시 `_state`가 `TitleState.needLogin`으로 설정됩니다.
2.  유저가 "S T A R T" 버튼을 탭하면 `_showLoginDialog()`가 호출됩니다.
3.  `_state`가 `readyToStart`가 아니므로, 로그인 선택 다이얼로그(`_GlassDialog`)가 표시됩니다.
4.  유저가 다이얼로그에서 "게스트로 시작하기" 버튼을 탭하면 `_guestLogin()`이 호출됩니다.

### 🔍 주요 함수 분석: `_guestLogin()`
게스트 계정 생성을 요청하고 성공 시 서버로부터 티켓을 발급받기 위해 상태 체크로 넘어갑니다.

1.  `_state`를 `TitleState.loading`으로 변경합니다.
2.  `POST /auth/guest-login` API를 호출합니다.
3.  **성공 시 (HTTP 200)**:
    *   응답으로 받은 `access_token`과 `user_id`를 로컬 스토리지에 저장합니다.
    *   `_checkStoryStatus()` 함수를 호출하여 프롤로그 진입용 티켓을 정상적으로 발급받아 스토리로 이동합니다.
4.  **실패 시 (`DioException`)**:
    *   서버 연결 실패 혹은 기타 에러 발생 시 `SnackBar`로 에러 메시지를 표시합니다.
    *   `_state`를 `TitleState.needLogin`으로 되돌려 유저가 재시도할 수 있도록 합니다. (오프라인 무단 진입 차단)

### ⭐ 코드 리뷰 포인트
*   **일관된 스토리 진입 파이프라인**: 프롤로그(`intro_1`) 역시 하드코딩된 빈 티켓이 아닌, 기존 유저와 동일하게 `_checkStoryStatus()`를 거쳐 서버로부터 정식 JWT 티켓을 발급받아 진입하도록 구조를 일원화하여 보안과 유지보수성을 높였습니다.

---

## 3. 🛠️ (참고) 개발자 치트 모드 시나리오 (`TitleScreen`)
※ 정식 출시 전 제거되어야 하는 개발자 디버그 패널 작동 로직입니다.

1.  **진입점**: 우측 상단 벌레 아이콘(`Icons.bug_report_outlined`)에 연결된 `GestureDetector`의 `onLongPress` 이벤트를 통해 `_showAdminPanel()` 함수가 호출됩니다.
2.  **`_showAdminPanel()`**:
    *   `AlertDialog`를 통해 어드민 키, 오프라인 일수, 시간 조작 값을 입력받는 `TextField`들을 표시합니다.
    *   '치트 적용 및 시작' 버튼 클릭 시, 아래의 API들을 순차적으로 호출합니다.
3.  **[API 호출 1] 치트 로그인 (오프라인 일수 조작)**
    *   **Endpoint:** `POST /admin/login`
    *   **Headers:** `admin-key` (String)
    *   **Query Parameters:** `user_id`, `cheat_offline_days`
4.  **[API 호출 2] 치트 스토리 체크 (시간 조작)**
    *   **Endpoint:** `GET /admin/check-story`
    *   **Headers:** `admin-key` (String)
    *   **Query Parameters:** `cheat_hour`
5.  **결과 처리**: 일반 `_checkStoryStatus` 로직과 동일하게, API 응답 결과에 따라 `StoryScreen` 또는 `LobbyScreen`으로 즉시 진입합니다.

---

## 4. 로비 화면 및 서버 시간 동기화 (`LobbyScreen`)
유저의 재화 상태를 표시하고, 서버와 동기화된 시간에 따라 UI를 변경하며, 시간대 변경 시 자동 스토리 진입을 체크하는 메인 허브입니다.

*   **핵심 파일:** `frontend/lib/screens/lobby/lobby_screen.dart`

### 🔄 상세 동작 흐름 (초기화)
1.  `initState()`에서 `_loadLobbyData()`를 호출하며 `_isLoading = true` 상태로 시작합니다.
2.  **시간 동기화 수행**:
    *   `GET /server-time` API 요청 전(`requestTime`)과 후(`responseTime`)에 `DateTime.now()`를 기록합니다.
    *   왕복 지연 시간의 절반인 `latency = responseTime.difference(requestTime) ~/ 2`를 계산합니다.
    *   `_timeOffset = (서버시간 + latency) - 현재 기기시간` 공식을 통해 기기와 서버 시간의 정확한 차이를 `Duration` 객체로 저장합니다.
3.  **유저 상태 로드**: `GET /user/status` API를 호출하여 `_playerName`, `_ap`, `_money` 상태 변수를 업데이트합니다.
4.  **타이머 시작**: 모든 데이터 로드 후 `_startTimeMonitor()`를 호출하여 10초 주기의 백그라운드 시간 감시를 시작합니다.

### 🔍 주요 함수 분석: `_startTimeMonitor` & `_handleTimeBoundaryCrossed`
*   **시간 유추**: `_startTimeMonitor`는 10초마다 `DateTime.now().add(_timeOffset)`을 통해 보정된 현재 서버 시간을 '유추'합니다.
*   **경계 감지**: 유추된 시간이 기존 시간(`_serverHour`)과 시간대(`_getZoneCode`)가 다르거나, 날짜(`_serverDay`)가 변경된 경우 `_handleTimeBoundaryCrossed`를 트리거합니다.
*   **서버 검증**: `_handleTimeBoundaryCrossed`는 먼저 `POST /verify-time` API를 호출하여 클라이언트의 시간대 변경 감지가 정확한지 서버에 더블 체크합니다.
*   **상태 갱신 (검증 성공 시)**:
    *   **자정 경과 시**: `POST /login`을 호출하여 서버의 일일 초기화 로직(AP 충전 등)을 트리거하고, `GET /user/status`로 갱신된 재화 정보를 다시 불러옵니다.
    *   **스토리 체크**: `GET /check-story`를 호출하여 새로운 시간대에 자동 재생할 스토리가 있는지 확인합니다.
    *   **분기**: 스토리가 있으면 `StoryScreen`으로 이동시키고, 없으면 로비의 시간(`_serverHour`, `_serverDay`)만 갱신한 후 `_startTimeMonitor`를 재시작합니다.

### ⭐ 코드 리뷰 포인트
*   **정밀한 시간 동기화**: 단순 서버 시간 요청이 아닌, API 왕복 지연시간(latency)을 계산하여 `_timeOffset`을 보정하는 방식은 시간 동기화의 정밀도를 크게 향상시킵니다. 이는 시간 기반 이벤트가 중요한 게임에서 필수적인 로직입니다.
*   **효율적인 백그라운드 작업**: 매초 서버에 시간을 묻는 대신, 한 번 계산한 `_timeOffset`을 바탕으로 클라이언트에서 시간을 유추하고, 중요한 경계선에서만 서버와 통신하는 방식은 매우 효율적이며 서버 부하를 줄여줍니다.
*   **방어적 로직**: 클라이언트의 시간 감지를 100% 신뢰하지 않고, `verify-time` API를 통해 서버에 한 번 더 확인하는 과정은 시스템의 안정성을 높이는 좋은 방어 코드입니다.

---

## 5. 스토리 진행 및 완료 시나리오 (`StoryScreen`)
JSON 형식의 대본을 파싱하여 스토리 연출을 담당하며, 유저의 선택지를 처리하고 스토리 완료 시 서버에 결과를 전송합니다.

*   **핵심 파일:** `frontend/lib/screens/story/story_screen.dart`

### 🔄 상세 동작 흐름 (초기화)
1.  `initState()`에서 `_loadStoryScript()`를 호출합니다.
2.  `storyId`의 접두사(`intro_`, `MAIN_` 등)와 `heroineName`을 조합하여 `assets/scripts/...` 내의 정확한 JSON 파일 경로를 동적으로 생성합니다.
3.  `rootBundle.loadString`으로 파일을 읽고 `jsonDecode`를 통해 `_scriptLines` (`List<dynamic>`)에 저장합니다.
4.  첫 번째 대본(`_scriptLines[0]`)의 시각 정보(`bg_image`, `character_image`)를 `_updateVisuals`를 통해 선제적으로 적용합니다.

### 🔍 주요 함수 분석: 상호작용 및 분기 처리
*   **`_nextStory()` (터치 이벤트 핸들러)**:
    *   `if (_isChoiceMode) return;` 코드를 통해 선택지가 활성화된 상태에서는 화면 터치를 무시하는 핵심적인 방어 로직을 포함합니다.
    *   현재 대사 라인에 `"action": "choice"`가 있으면, `_isChoiceMode`를 `true`로 설정하고 선택지 UI를 렌더링하며 대사 진행을 멈춥니다.
    *   다른 액션이 없으면 `_advanceLine()`을 호출하여 다음 대사로 진행합니다.
*   **`_onChoiceSelected()` (선택지 버튼 핸들러)**:
    *   선택한 `choice` 객체에 `"bonus_score"`가 있으면 `_earnedBonusScore` 변수에 값을 저장합니다.
    *   `"next_lines"` 배열이 존재하면, `_scriptLines.insertAll(_currentIndex + 1, nextLines)`를 통해 현재 대사 바로 다음에 선택지 전용 대사들을 '삽입'합니다. 이는 별도의 분기 로직 없이 스크립트 흐름을 자연스럽게 변경하는 매우 효율적인 방식입니다.
    *   `_isChoiceMode`를 `false`로 되돌리고 `_advanceLine()`을 호출하여 삽입되거나 원래 있던 다음 대사로 진행합니다.

### 🔍 주요 함수 분석: `_completeStory()`
대본을 끝까지 다 읽었을 때, 스토리 완료 결과를 서버에 전송합니다.

1.  `_earnedBonusScore`가 0이 아니면, `dart_jsonwebtoken` 패키지를 사용해 호감도 점수를 payload에 담은 JWT(`bonus_token`)를 **클라이언트에서 직접 생성**합니다. 이 때 사용하는 비밀 키는 `.env` 파일에서 안전하게 로드됩니다.
2.  `POST /complete-story` API를 호출합니다. Body에 `story_ticket`과 생성된 `bonus_token`(선택적)을 담아 전송합니다.
3.  성공 시 `Navigator.pushReplacement`로 `LobbyScreen`으로 돌아가며 스토리 진행 스택을 완전히 제거합니다.

### ⭐ 코드 리뷰 포인트
*   **동적 스크립트 삽입**: 선택지 분기를 `if/else`나 `switch`로 하드코딩하지 않고, `List.insertAll`을 사용해 스크립트 자체를 동적으로 재구성하는 방식은 확장성이 매우 뛰어나고 유지보수가 용이합니다. 새로운 분기를 추가할 때 Dart 코드 수정 없이 JSON만 변경하면 됩니다.
*   **클라이언트 측 JWT 생성**: 호감도 점수처럼 민감하지 않지만 위변조는 막아야 하는 데이터를 클라이언트에서 직접 JWT로 서명하여 보내는 것은 서버의 부담을 줄이는 흥미로운 접근 방식입니다. (기기 시간 오차로 인한 백엔드 검증 실패(Expired)를 막기 위해 `expiresIn` 속성은 제거하고, 서버의 `story_ticket`으로 1차 시간 검증을 의존하도록 설계되었습니다.)
*   **방어 코드**: `_nextStory`의 `_isChoiceMode` 체크, 이미지 로드 실패 시 `errorBuilder`를 통한 대체 UI 표시 등 예외 상황에 대한 방어 코드가 잘 구현되어 있어 앱의 안정성을 높입니다.