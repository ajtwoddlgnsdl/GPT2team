# 스토리 대본 파일명 설정 규칙 및 디렉터리 매핑 가이드

이 문서는 유저의 게임 진행 상태(Game State)에 따른 백엔드 스토리 ID 생성 규칙과 프론트엔드의 실제 파일 매핑 경로를 상세히 정리한 가이드입니다.

## 🕰️ 시간대(TimeZone) 표기 기준
스토리 파일명에 들어가는 시간대(Zone) 명칭은 `config.py`의 `TimeZone` Enum 값을 따릅니다.
* **06~12시**: `아침`
* **12~18시**: `낮`
* **18~24시**: `저녁`
* **24~06시**: `새벽`

---

## 1. 프롤로그 1단계 (GameState: INTRO_1)
가장 처음 게임을 시작할 때 진행되는 공통 튜토리얼 성격의 스토리입니다.

* **진행 상태 (GameState)**: `INTRO_1`
* **스토리 ID (storyId)**: `intro_1_prologue`
* **히로인 이름 (heroineName)**: `TUTORIAL_DUMMY` (가상 이름)
* **프론트엔드 실제 파일 경로**:
  * `assets/scripts/intro1/intro_1_prologue.json`
  * *특이사항*: 이 단계는 히로인별 개별 하위 폴더를 거치지 않고 `intro1` 폴더 바로 아래에서 파일을 찾습니다.

---

## 2. 프롤로그 2단계 / 공통 루트 (GameState: INTRO_2)
튜토리얼 종료 후 메인 히로인이 확정되기 전, 각 시간대별로 특정 히로인과 마주치는 스토리입니다.

* **진행 상태 (GameState)**: `INTRO_2`
* **스토리 ID (storyId)**: `day{진행일수}_{시간대}_{히로인이름}`
  * *예시 1*: `day1_낮_코토리` (1일차 12~18시 사이 접속 시)
  * *예시 2*: `day3_아침_이서연` (3일차 06~12시 사이 접속 시)
* **프론트엔드 실제 파일 경로**:
  * `assets/scripts/intro2/{히로인이름}/day{진행일수}_{시간대}_{히로인이름}.json`
  * *예시 파일 경로*: `assets/scripts/intro2/코토리/day1_낮_코토리.json`

---

## 3. 메인 스토리 단계 (GameState: MAIN)
특정 히로인의 루트로 진입한 후, `STORY_CONFIG`의 스케줄러(JSON) 조건에 맞춰 진행되는 메인 스토리입니다.

* **진행 상태 (GameState)**: `MAIN`
* **스토리 ID (storyId)**: `MAIN_day{진행일수}_{시간대}_{히로인이름}`
  * *예시 1*: `MAIN_day15_저녁_이서연` (이서연 루트 15일차에 저녁(18~24시) 스토리가 예정된 경우)
* **프론트엔드 실제 파일 경로**:
  * `assets/scripts/main/{히로인이름}/MAIN_day{진행일수}_{시간대}_{히로인이름}.json`
  * *예시 파일 경로*: `assets/scripts/main/이서연/MAIN_day15_저녁_이서연.json`

---

## 4. 엔딩 단계 (GameState: END)
메인 스토리가 모두 종료된 후 호감도(Affection) 수치에 따라 결정된 분기별 엔딩 스토리입니다.

* **진행 상태 (GameState)**: `END`
* **엔딩 분기 결정 기준 (호감도)**:
  * 30 미만: `BAD` (배드 엔딩)
  * 30 이상 ~ 80 미만: `NORMAL` (노멀 엔딩)
  * 80 이상: `TRUE` (트루/해피 엔딩)
* **스토리 ID (storyId)**: `ENDING_{엔딩종류}_{히로인이름}`
  * *예시 1*: `ENDING_TRUE_이서연`
  * *예시 2*: `ENDING_BAD_코토리`
* **프론트엔드 실제 파일 경로**:
  * `assets/scripts/ending/{히로인이름}/ENDING_{엔딩종류}_{히로인이름}.json`
  * *예시 파일 경로*: `assets/scripts/ending/이서연/ENDING_TRUE_이서연.json`

---

## 💡 요약 규칙 (프론트엔드 디렉터리 분기 로직)
프론트엔드 `story_screen.dart`에서는 백엔드에서 전달해주는 `story_id`의 **접두사(Prefix)**를 바탕으로 폴더(Folder)를 자동으로 파악합니다.

| 스토리 ID 접두사 | 배정되는 최상위 폴더 | 히로인 하위폴더 유무 | 최종 경로 예시 |
| :--- | :--- | :--- | :--- |
| `intro_` 시작 | `intro1` | X | `assets/scripts/intro1/intro_1_prologue.json` |
| `MAIN_` 시작 | `main` | O | `assets/scripts/main/리안/MAIN_day11_저녁_리안.json` |
| `ENDING_` 시작 | `ending` | O | `assets/scripts/ending/리안/ENDING_NORMAL_리안.json` |
| (위 셋 다 아닐 경우) | `intro2` | O | `assets/scripts/intro2/리안/day2_저녁_리안.json` |
