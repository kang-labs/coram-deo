"""Firebase 에뮬레이터(PC 안의 가짜 서버)에 시험용 데이터를 넣어요. 실제 서버는 건드리지 않아요.

사용법 (프로젝트 폴더에서, 에뮬레이터를 켠 다음):
    firebase emulators:start --only firestore,auth --project coram-deo-biblekang
    python tool/dev/emu_setup.py

앱은 확인용 빌드로 붙여요:
    flutter build apk --release --dart-define=USE_FIREBASE_EMULATOR=true

넣는 것:
- seed.py의 반 7개 (제자대학2학기는 12주 일정 포함)
- 제자대학2학기 반장 이름 'TestChief'(adb로 한글을 못 넣어서 영문), 반 코드 '4321'
- 시험용 관리자 계정 (비밀번호 TEST_ADMIN_PIN, 에뮬레이터 안에서만 쓰는 값)
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
import seed  # noqa: E402  (같은 폴더의 seed.py)

PROJECT = "coram-deo-biblekang"
FS = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
AUTH = f"http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts"
TEST_ADMIN_PIN = "135790"  # 에뮬레이터 전용 시험 값 (실제 관리자 비밀번호 아님)


def call(method: str, url: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": "Bearer owner", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as res:
        raw = res.read()
        return json.loads(raw) if raw else {}


def put(path: str, doc: dict) -> None:
    call("PATCH", f"{FS}/{path}", {"fields": {k: seed.to_value(v) for k, v in doc.items()}})


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    for cid, doc in seed.build_courses().items():
        if cid == "jedae2":
            doc = {**doc, "leaders": {"chief": "TestChief", "treasurer": ""}}
        put(f"courses/{cid}", doc)
    put("courses/jedae2/private/codes", {"code": "4321"})
    try:
        call("POST", AUTH, {"email": "bible4217@gmail.com", "password": TEST_ADMIN_PIN, "emailVerified": True})
    except urllib.error.HTTPError as e:
        if e.code != 400:  # 400 = 이미 있는 계정 (에뮬레이터를 끄지 않고 다시 돌릴 때)
            raise
    print("에뮬레이터 준비 끝: 반 7개, 제자대학2학기 반장 TestChief / 코드 4321, 시험 관리자 계정")


if __name__ == "__main__":
    main()
