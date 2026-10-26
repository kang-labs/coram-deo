"""firestore.rules 확인 (Firestore 에뮬레이터에서). 실제 서버는 건드리지 않아요.

사용법 (프로젝트 폴더에서):
    firebase emulators:exec --only firestore "python tool/dev/rules_test.py"

에뮬레이터는 서명 없는 토큰을 받아 주므로, 익명 사용자·관리자 등을 흉내 내 규칙이 막고 여는지 봐요.
"""

from __future__ import annotations

import base64
import json
import sys
import urllib.error
import urllib.request

PROJECT = "coram-deo-biblekang"
BASE = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
ADMIN_EMAIL = "bible4217@gmail.com"


def b64(d: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")


def token(uid: str, email: str | None = None, verified: bool = False, provider: str = "anonymous") -> str:
    payload = {
        "sub": uid, "user_id": uid, "aud": PROJECT, "iss": f"https://securetoken.google.com/{PROJECT}",
        "iat": 1700000000, "exp": 4000000000, "auth_time": 1700000000,
        "firebase": {"sign_in_provider": provider},
    }
    if email:
        payload["email"] = email
        payload["email_verified"] = verified
    return f"{b64({'alg': 'none', 'typ': 'JWT'})}.{b64(payload)}."


OWNER = "owner"  # 에뮬레이터에서 규칙을 건너뛰는 관리자 토큰 (준비용)


def val(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [val(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: val(x) for k, x in v.items()}}}
    raise TypeError(v)


def req(method: str, url: str, tok: str, body: dict | None = None) -> int:
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method,
                               headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r) as res:
            res.read()
            return res.status
    except urllib.error.HTTPError as e:
        e.read()
        return e.code


def put(path: str, fields: dict, tok: str, server_time: str | None = None) -> int:
    """문서 쓰기 (commit). server_time 필드는 서버 시각으로."""
    write = {"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/{path}",
                        "fields": {k: val(v) for k, v in fields.items()}}}
    if server_time:
        write["updateTransforms"] = [{"fieldPath": server_time, "setToServerValue": "REQUEST_TIME"}]
    return req("POST", f"{BASE}:commit", tok, {"writes": [write]})


def get(path: str, tok: str) -> int:
    return req("GET", f"{BASE}/{path}", tok)


def list_(path: str, tok: str) -> int:
    return req("GET", f"{BASE}/{path}", tok)


COURSE = {
    "name": "양육A반", "term": "", "weekday": 2, "time": "10:00", "order": 1, "visible": True,
    "weeks": [], "extras": [], "items": [{"id": "qt", "label": "큐티", "parts": []}], "guide": "",
    "program": "yangyuk", "cohort": 25, "semester": 0, "leaders": {"chief": "홍 길동A", "treasurer": "김영희"},
}

results: list[tuple[str, bool]] = []


def check(label: str, got: int, ok: bool) -> None:
    passed = (got == 200) == ok
    results.append((label, passed))
    print(f"{'통과' if passed else '실패'}  {label}  (응답 {got}, 기대 {'허용' if ok else '거절'})")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    # 준비: 반·코드 (규칙 건너뛰기)
    assert put("courses/c1", COURSE, OWNER) == 200
    assert put("courses/c1/private/codes", {"code": "1234"}, OWNER) == 200

    u1, u2, u3 = token("u1"), token("u2"), token("u3")
    admin = token("adm", ADMIN_EMAIL, True, "password")
    fake_admin = token("fake", ADMIN_EMAIL, False, "password")
    rec = {"name": "이순신", "record": {"1": {"qt": {"main": 3}}}}

    check("익명: 내 자리에 기록 올리기", put("courses/c1/members/u1", rec, u1, "updatedAt"), True)
    check("익명: 남의 자리에 쓰기", put("courses/c1/members/u2", rec, u1, "updatedAt"), False)
    check("익명: 모르는 필드 넣기", put("courses/c1/members/u1", {**rec, "x": 1}, u1, "updatedAt"), False)
    check("익명: 시각을 직접 넣기", put("courses/c1/members/u1", {**rec, "updatedAt": "x"}, u1), False)
    check("익명: 내 기록 읽기", get("courses/c1/members/u1", u1), True)
    check("익명: 없는 반에 기록 올리기", put("courses/nope/members/u1", rec, u1, "updatedAt"), False)
    big = {"name": "이순신", "record": {str(i): {} for i in range(61)}}
    check("익명: 주차 61개 넘는 기록", put("courses/c1/members/u1", big, u1, "updatedAt"), False)
    check("익명: 내 문서 지우기", req("DELETE", f"{BASE}/courses/c1/members/u9", token("u9")), True)
    check("익명: 남의 문서 지우기", req("DELETE", f"{BASE}/courses/c1/members/u1", u2), False)
    check("익명(반장 아님): 반 사람 목록 읽기", list_("courses/c1/members", u2), False)
    check("익명: 코드 읽기", get("courses/c1/private/codes", u1), False)

    check("반장 이름 소문자 그대로(앱은 대문자로 보냄)", put("courses/c1/leaders/u2", {"name": "홍길동a", "code": "1234"}, u2, "at"), False)
    check("반장 이름(띄어쓰기·대소문자 맞춤)+맞는 코드", put("courses/c1/leaders/u2", {"name": "홍길동A", "code": "1234"}, u2, "at"), True)
    check("반장 이름+틀린 코드", put("courses/c1/leaders/u3", {"name": "홍길동A", "code": "0000"}, u3, "at"), False)
    check("다른 이름+맞는 코드", put("courses/c1/leaders/u3", {"name": "박철수", "code": "1234"}, u3, "at"), False)
    check("총무 이름+맞는 코드", put("courses/c1/leaders/u3", {"name": "김영희", "code": "1234"}, u3, "at"), True)
    check("남의 uid로 반장 만들기", put("courses/c1/leaders/zz", {"name": "홍길동A", "code": "1234"}, u1, "at"), False)
    check("반장: 반 사람 목록 읽기", list_("courses/c1/members", u2), True)
    check("반장: 코드 읽기", get("courses/c1/private/codes", u2), False)
    check("반장: 남의 기록 쓰기", put("courses/c1/members/u1", rec, u2, "updatedAt"), False)

    check("관리자: 코드 읽기", get("courses/c1/private/codes", admin), True)
    check("관리자: 반 사람 목록 읽기", list_("courses/c1/members", admin), True)
    check("반장: 남의 문서 지우기", req("DELETE", f"{BASE}/courses/c1/members/u1", u2), False)
    check("관리자: 반 사람 지우기", req("DELETE", f"{BASE}/courses/c1/members/u1", admin), True)
    check("관리자: 반장 인정 풀기", req("DELETE", f"{BASE}/courses/c1/leaders/u3", admin), True)
    check("관리자: 없는 문서 지우기(괜찮음)", req("DELETE", f"{BASE}/courses/c1/leaders/none", admin), True)
    check("이메일 확인 안 된 관리자 흉내: 코드 읽기", get("courses/c1/private/codes", fake_admin), False)
    check("관리자: 반 저장(반장 정보 유지)", put("courses/c1", COURSE, admin, "updatedAt"), True)
    no_leaders = {k: v for k, v in COURSE.items() if k != "leaders"}
    check("관리자(예전 앱): 반장 정보 지우며 저장", put("courses/c1", no_leaders, admin, "updatedAt"), False)
    check("익명: 반 저장", put("courses/c1", COURSE, u1, "updatedAt"), False)

    check("관리자: 학기 1로 시작", put("config/app", {"semester": 1}, admin, "startedAt"), True)
    check("관리자: 학기 건너뛰기(3)", put("config/app", {"semester": 3}, admin, "startedAt"), False)
    check("관리자: 학기 2로", put("config/app", {"semester": 2}, admin, "startedAt"), True)

    failed = [label for label, ok in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} 통과")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
