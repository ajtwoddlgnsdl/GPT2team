# 🚀 정식 출시 전 개발자 치트 제거 지침서

이 문서는 정식 앱 배포 이전에 유저의 어뷰징(시간 조작, 스토리 무단 해금 등)을 막기 위해 **개발자 전용 치트 패널 및 관련 API를 제거하는 방법**을 안내합니다.
출시 전 반드시 아래의 단계들을 수행하여 치트 로직을 제거해 주세요.

---

## 1. 프론트엔드 (클라이언트) 수정 사항
**작업 파일:** `frontend/lib/screens/auth/title_screen.dart`

### ❌ 1-1. 치트 입력용 변수 삭제
`_TitleScreenState` 클래스 상단에 선언된 텍스트 컨트롤러 변수 3개를 삭제합니다.
```dart
final TextEditingController _adminKeyCtrl = TextEditingController(text: "여기에_어드민키_입력");
final TextEditingController _offlineDaysCtrl = TextEditingController(text: "1");
final TextEditingController _cheatHourCtrl = TextEditingController(text: "14");
```

### ❌ 1-2. 디버그 패널 함수 삭제
개발자용 다이얼로그 창을 띄우고 `/admin/login`, `/admin/check-story` API를 호출하는 아래 함수 전체를 삭제합니다.
```dart
// 💡 개발자 전용 디버그 패널
void _showAdminPanel() {
  showDialog(
    ...
  );
}
```

### ❌ 1-3. 타이틀 화면의 벌레(버그) 모양 아이콘 삭제
`build(BuildContext context)` 내부의 `Stack` 위젯 안에 있는 디버그 버튼 코드를 삭제합니다.
```dart
// 💡 개발자 전용 디버그 버튼 (우측 상단)
Positioned(
  top: 50,
  right: 20,
  child: IconButton(
    icon: const Icon(Icons.bug_report, color: Colors.grey, size: 30),
    onPressed: _showAdminPanel,
  ),
),
```

---

## 2. 백엔드 (서버) 수정 사항
**작업 파일:** `backend/app/routers.py`

### ❌ 2-1. 어드민 전용 라우터(API) 삭제
파일의 가장 하단에 위치한 `🛠️ 개발자(Admin) 전용 치트 API` 섹션의 아래 두 가지 라우터와 함수를 완전히 삭제합니다.

1. `@router.post("/admin/login")` 로 시작하는 `admin_login` 함수 전체
2. `@router.get("/admin/check-story")` 로 시작하는 `admin_check_story` 함수 전체

---

## 🛡️ 보안 및 검수 포인트 (중요)
* **백엔드 API 제거 필수:** 혹시라도 프론트엔드에서 버튼(UI)을 지우는 것을 깜빡하거나 유저가 앱을 변조하더라도, **백엔드의 API 2개가 삭제되어 있다면 해킹은 불가능**합니다. 백엔드 삭제를 최우선으로 진행하세요.
* **어드민 키 변경:** 다른 운영 툴(Admin Web 등)을 위해 `ADMIN_SECRET_KEY`를 유지해야 한다면, 운영 환경(Production) 배포 시 `config.py`나 환경 변수(.env)의 값을 매우 복잡하고 긴 문자열로 변경해야 합니다.