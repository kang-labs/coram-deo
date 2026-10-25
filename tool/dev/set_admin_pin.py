"""관리자 숫자 비밀번호(6자리)를 정하거나 바꿉니다. 비밀번호는 이 창에 직접 입력하고 어디에도 저장하지 않아요.

사용법 (프로젝트 폴더에서):
    firebase projects:list                  # 먼저 한 번: 로그인 토큰을 새로 받아요 (1시간 지나면 만료)
    python tool/dev/set_admin_pin.py        # 비밀번호 정하기 (숫자 6자리를 두 번 입력)
    python tool/dev/set_admin_pin.py --providers-only   # 로그인 방식만 켜기 (이메일/비밀번호, 익명)

하는 일:
1. Firebase 로그인 방식 켜기: 이메일/비밀번호(관리자 숫자 비밀번호용), 익명(사람들 기록 올리기용)
2. 관리자 계정(lib/core/admin.dart의 첫 이메일)에 비밀번호를 넣어요. 구글로 로그인한 적 있는 같은 계정에 비밀번호가 더해지고,
   이메일 확인됨 상태로 둬요(firestore.rules의 isAdmin이 email_verified를 봐요).

인증: seed.py와 같이 firebase CLI 로그인 토큰(프로젝트 소유자 권한)을 써요.
"""

from __future__ import annotations

import argparse
import getpass
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

PROJECT = "coram-deo-biblekang"
ADMIN_EMAIL = "bible4217@gmail.com"  # lib/core/admin.dart adminEmails 첫 번째와 같게
ADMIN_API = f"https://identitytoolkit.googleapis.com/admin/v2/projects/{PROJECT}/config"
ACCOUNTS = f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts"


def access_token() -> str:
    path = pathlib.Path.home() / ".config" / "configstore" / "firebase-tools.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))["tokens"]["access_token"]
    except (OSError, KeyError, ValueError) as e:
        sys.exit(f"토큰을 못 읽었어요 ({path}): {e}\n먼저 `firebase login` 후 `firebase projects:list`를 실행해 주세요.")


def call(method: str, url: str, token: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8",
            "x-goog-user-project": PROJECT,
        },
    )
    try:
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        hint = "\n토큰이 만료됐을 수 있어요: `firebase projects:list` 실행 후 다시 해 주세요." if e.code == 401 else ""
        sys.exit(f"요청 실패 ({e.code}): {detail[:300]}{hint}")


def enable_providers(token: str) -> None:
    """이메일/비밀번호와 익명 로그인 켜기 (이미 켜져 있으면 그대로)"""
    mask = "signIn.email.enabled,signIn.email.passwordRequired,signIn.anonymous.enabled"
    call(
        "PATCH",
        f"{ADMIN_API}?updateMask={mask}",
        token,
        {"signIn": {"email": {"enabled": True, "passwordRequired": True}, "anonymous": {"enabled": True}}},
    )
    print("로그인 방식을 켰어요: 이메일/비밀번호, 익명")


def ask_pin() -> str:
    for _ in range(3):
        pin = getpass.getpass("새 관리자 비밀번호 (숫자 6자리, 화면에 안 보여요): ").strip()
        if not re.fullmatch(r"\d{6}", pin):
            print("숫자 6자리로 넣어 주세요.")
            continue
        if getpass.getpass("한 번 더 입력: ").strip() != pin:
            print("두 번 입력한 값이 달라요. 다시 해 주세요.")
            continue
        return pin
    sys.exit("비밀번호를 정하지 못했어요.")


def set_pin(token: str, pin: str) -> None:
    found = call("POST", f"{ACCOUNTS}:lookup", token, {"email": [ADMIN_EMAIL]}).get("users", [])
    if found:
        call("POST", f"{ACCOUNTS}:update", token, {"localId": found[0]["localId"], "password": pin, "emailVerified": True})
        print(f"{ADMIN_EMAIL} 계정에 비밀번호를 넣었어요.")
    else:
        call("POST", ACCOUNTS, token, {"email": ADMIN_EMAIL, "password": pin, "emailVerified": True})
        print(f"{ADMIN_EMAIL} 계정을 만들고 비밀번호를 넣었어요.")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="관리자 숫자 비밀번호 정하기")
    ap.add_argument("--providers-only", action="store_true", help="로그인 방식만 켜고 비밀번호는 안 바꿈")
    args = ap.parse_args()
    token = access_token()
    enable_providers(token)
    if args.providers_only:
        return
    set_pin(token, ask_pin())
    print("앱의 설정 > 관리자 모드에서 이 숫자 6자리로 로그인하면 돼요.")


if __name__ == "__main__":
    main()
