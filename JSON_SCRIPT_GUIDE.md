# 📝 게임 스토리 JSON 대본 작성 가이드

이 문서는 게임 내 스토리(대화, 시각적 연출, 선택지 분기 등)를 구성하는 JSON 스크립트를 작성하는 방법을 안내합니다.

---

## 📂 1. 폴더 구조 및 파일명 규칙
프론트엔드는 파일명의 **접두사(Prefix)** 를 읽어 자동으로 폴더 경로를 찾습니다. 스토리의 종류에 맞춰 아래 폴더에 `.json` 파일을 넣어주세요.

* **`assets/scripts/intro1/`**: 프롤로그 및 튜토리얼 (예: `intro_1_prologue.json`)
* **`assets/scripts/intro2/{히로인이름}/`**: 공통 루트 및 공략 전 스토리 (예: `assets/scripts/intro2/이서연/day0_아침_이서연.json`)
* **`assets/scripts/main/{히로인이름}/`**: 메인 히로인 개별 루트 (예: `assets/scripts/main/최시은/MAIN_day1_낮_최시은.json`)
* **`assets/scripts/ending/{히로인이름}/`**: 엔딩 스토리 (예: `assets/scripts/ending/코토리/ENDING_TRUE_코토리.json`)

---

## 📖 2. 대본 기본 구조
대본은 한 번의 화면 터치(씬) 단위로 이루어진 **객체(Object)들의 배열(Array)** 구조입니다.

### 🎨 기본 시각적/텍스트 필드
* `"bg_image"`: 배경 이미지 경로. 한 번 설정하면 다른 이미지로 덮어쓰기 전까지 계속 유지됩니다.
* `"character_image"`: 화면 중앙 캐릭터 스탠딩 이미지 경로. 마찬가지로 변경 전까지 계속 유지됩니다.
* `"speaker"`: 말하는 사람의 이름.
* `"text"`: 대화 내용.
* 💡 **특수 변수 `{name}`**: `speaker`나 `text` 안에서 `{name}`을 사용하면, 게임 내에서 **유저가 설정한 닉네임**으로 자동 변환되어 출력됩니다.

---

## ⚡ 3. 특수 액션 (`action`)
대화를 멈추고 특별한 동작을 수행해야 할 때 `"action"` 필드를 사용합니다.

### 3-1. 닉네임 입력 (`"action": "input_nickname"`)
유저에게 이름을 입력받는 팝업을 띄웁니다.
```json
{
  "action": "input_nickname"
}
```

### 3-2. 선택지 분기 (`"action": "choice"`)
화면에 선택지 버튼들을 띄우고 유저의 응답을 대기합니다.

* `"choices"`: 유저가 누를 수 있는 버튼 객체들의 배열입니다.
  * `"text"`: 버튼에 표시될 텍스트입니다.
  * `"bonus_score"`: (선택) 이 선택지를 골랐을 때 얻게 될 호감도 점수(정수형 숫자)입니다. 프론트엔드가 이를 읽어 자동으로 JWT로 변환합니다.
  * `"next_lines"`: (선택) 이 버튼을 눌렀을 때만 **이어서 출력될 대사 객체들의 배열**입니다. (자연스러운 분기 처리에 사용)

---

## 💡 4. 종합 작성 예시 (Example)
이 예시 하나에 모든 핵심 기능이 담겨 있습니다. 복사해서 템플릿으로 활용하세요.

```json
[
  {
    "bg_image": "assets/images/bg/lobby_afternoon.jpg",
    "character_image": "assets/images/character/heroine_normal.png",
    "speaker": "최시은",
    "text": "안녕, {name}? 나한테 물어볼 거라도 있어?"
  },
  {
    "action": "choice",
    "speaker": "최시은",
    "text": "(시은이가 대답을 기다리고 있다. 빨리 골라보자.)",
    "choices": [
      {
        "text": "오늘 날씨 참 좋다, 그치?",
        "bonus_score": 5, 
        "next_lines": [
          {
            "character_image": "assets/images/character/heroine_smile.png",
            "speaker": "최시은",
            "text": "응! 나도 그렇게 생각했어."
          }
        ]
      },
      {
        "text": "(가만히 있는다.)",
        "next_lines": [
          {
            "character_image": "assets/images/character/heroine_sad.png",
            "speaker": "최시은",
            "text": "뭐야... 할 말 없으면 간다?"
          }
        ]
      }
    ]
  },
  {
    "speaker": "최시은",
    "text": "어쨌든, 나중에 로비에서 또 보자!"
  }
]
```