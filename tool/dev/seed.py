"""처음 등록할 반 7개를 Firestore에 넣습니다 (설계서 docs/DESIGN.md §2·§4·§5).

사용법:
    firebase projects:list          # 먼저 한 번: 로그인 토큰을 새로 받아요 (1시간 지나면 만료)
    python tool/dev/seed.py --dry-run          # 보낼 JSON만 출력
    python tool/dev/seed.py                    # 7개 반 모두 넣기 (같은 id 문서는 통째로 덮어씀!)
    python tool/dev/seed.py --only jedae2      # 한 반만

인증: ~/.config/configstore/firebase-tools.json 의 tokens.access_token (firebase CLI 로그인 계정).
관리자(프로젝트 소유자) 권한의 REST 호출이라 보안 규칙과 상관없이 써져요.

기본 항목·기록요령은 lib/core/models/course_defaults.dart 와 같아야 해요 — 바꾸면 함께 고칩니다.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import sys
import urllib.error
import urllib.request

PROJECT = "coram-deo-biblekang"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def part(label: str, type_: str = "mark", pid: str = "main") -> dict:
    return {"id": pid, "label": label, "type": type_}


# 칸 id는 폰 기록과 이어지는 키 (칸 하나면 'main'). 앱 lib/core/models/course_defaults.dart 와 같게.
DEFAULT_ITEMS = [
    {"id": "attend", "label": "훈련", "parts": [part("출석", "attend", "att"), part("후기", pid="review")]},
    {"id": "prep", "label": "교재예습", "parts": [part("교재예습")]},
    {"id": "book", "label": "필독서 읽기", "parts": [part("필독서")]},
    {"id": "bible", "label": "성경읽기", "parts": [part("성경", "days")]},
    {"id": "qt", "label": "큐티", "parts": [part("큐티", "days")]},
    {"id": "prayer", "label": "기도", "parts": [part("기도", "days")]},
    {"id": "dawn", "label": "새벽기도", "parts": [part("새벽", "dawn")]},
    {"id": "task", "label": "강사 특별과제", "parts": [part("과제")]},
    {"id": "verse", "label": "구절암송", "parts": [part("암송", "ox")]},
    {"id": "monday", "label": "월요목회 도고기도", "parts": [part("도고")]},
    {"id": "friday", "label": "금요기도회",
     "parts": [part("출석", pid="att"), part("후기", pid="review"), part("강단기도", pid="pulpit")]},
    {"id": "festival", "label": "축제예배/후기", "parts": [part("참석", pid="att"), part("후기", pid="review")]},
    {"id": "passion", "label": "열정예배/후기", "parts": [part("참석", pid="att"), part("후기", pid="review")]},
    {"id": "cell", "label": "셀가족모임", "parts": [part("셀")]},
    {"id": "happy", "label": "행복모임 인도", "parts": [part("행복")]},
]

DEFAULT_GUIDE = """- 출석: 출석(○) 지각(지)로 표기, 결석 3회부터는 과락 처리됩니다. 꼭 반장을 통해 사전 연락하세요.
- 성경: 1일 맥체인 성경읽기(셀라이프 캘린더) 읽은 날짜 기록 / 7일간 다 했을 경우 '7'이라고 표시
- 큐티: <셀라이프> 한 날짜 기록 / 7일간 다 했을 경우 '7'이라고 표시
- 교재예습, 필독서 읽기, 과제, 후기: 했으면(○), 안 했으면(X)로 표시
  - 교재예습: 말씀구절을 손으로 직접 기록합니다(5절 이상의 구절은 첫 구절, 마지막 구절만 기록). 예습하면 더 큰 은혜가 있습니다.
  - 필독서 읽기: 정해진 주에 정해진 분량만큼 읽고 나눔을 준비합니다.
- 축제예배, 셀가족모임, 행복모임, 금요기도회: 참석(○) 불참(X)로 표기
- 기도: 한 시간만큼 기록 / 하루 1시간, 일주일간 7시간 했으면 '7'이라고 표시
- 새벽기도: 주 3회 참석: 0, 2회 참석: −1, 1회 참석: −2, 미참석: −3"""

# 수업 요일: DateTime.weekday (월1 … 일7)
TUE, THU, SAT = 2, 4, 6

# (id, 이름, 요일, 시간)
COURSES = [
    ("yangyuk_a", "양육A반", TUE, "10:00"),
    ("yangyuk_bc", "양육B,C반", SAT, "18:00"),
    ("jejahak_a", "제자학교A반", TUE, "10:00"),
    ("jejahak_b", "제자학교B반", SAT, "14:00"),
    ("jedae1_a", "제자대학1학기A반", THU, "10:00"),
    ("jedae1_b", "제자대학1학기B반", THU, "20:00"),
    ("jedae2", "제자대학2학기", SAT, "18:00"),
]

BOOK1 = "세계비전의 기쁨 I"
BOOK2 = "세계비전의 기쁨 II"

# 제자대학2학기 (2026-10-14 받은 새 일정표, §4). (날짜, 교재, 훈련 내용, 암송구절, 나눔, 휴강)
# 여러 과는 줄을 나눠 넣어요. 암송구절은 장절만 줄마다(본문은 관리자가 앱에서 적어요 — 저작권). 나눔은 한 줄.
JEDAE2_WEEKS = [
    ("2026-09-12", BOOK1, "1과 위대한 부르심", "고후 1:20\n엡 6:10,11", "", False),
    ("2026-09-19", BOOK1, "2과 생활 속에서 행복모임을 열라\n3과 승리를 확신하는 삶", "딤후 2:3,4\n눅 16:10",
     "제자삼는 세계비전 part1 1,2장", False),
    ("2026-09-26", "", "추석 연휴", "", "", True),
    ("2026-10-03", BOOK1, "4과 셀가족모임 말씀 나눔 인도법\n5과 순종하는 제자", "딤후 2:21\n딤전 4:7,8", "3,4장", False),
    ("2026-10-10", BOOK1, "6과 성숙한 신앙 인격과 사역\n7과 세계비전을 이루시는 성령님", "고전 9:25\n고전 9:27", "5장", False),
    ("2026-10-17", BOOK1, "8과 배가 번식을 열망하라\n9과 하나님이 기뻐하시는 사명자", "요 4:35\n행 2:47", "part2 1,2장", False),
    ("2026-10-24", BOOK2, "1과 역사의 주역", "딤후 2:2\n마 9:38", "3,4장", False),
    ("2026-10-31", BOOK2, "2과 행복이 넘치는 셀가족\n3과 인턴Intern을 세워라", "빌 4:9\n롬 16:4", "5장", False),
    ("2026-11-07", BOOK2, "4과 영광스러운 셀리더", "단 12:3\n딤후 4:8", "나가든지 보내든지 하라 part 1,2", False),
    ("2026-11-14", BOOK2, "5과 비전과 리더십", "창 1:28\n요 15:8", "part3", False),
    ("2026-11-21", BOOK2, "7과 행복모임의 확장\n8과 성령님과 함께하는 삶", "마 13:33\n마 13:44", "part4", False),
    ("2026-11-28", BOOK2, "9과 꿈에도 소원은 재생산", "막 16:15\n마 28:18-20", "part5", False),
]

JEDAE2_EXTRAS = [
    {"label": "개강", "date": "2026-09-06", "title": "OT"},
    {"label": "졸업예배", "date": "2026-12-06", "title": ""},
]


def verses(refs: str) -> list[dict]:
    """줄마다 장절 하나 → [{ref, text: ""}] (본문은 비워 둬요)"""
    return [{"ref": r.strip(), "text": ""} for r in refs.split("\n") if r.strip()]


def build_courses() -> dict[str, dict]:
    out = {}
    for order, (cid, name, weekday, time) in enumerate(COURSES, start=1):
        doc = {
            "name": name,
            "term": "",
            "weekday": weekday,
            "time": time,
            "order": order,
            "visible": True,
            "weeks": [],
            "extras": [],
            "items": DEFAULT_ITEMS,
            "guide": DEFAULT_GUIDE,
        }
        if cid == "jedae2":
            doc["term"] = "22기 2학기"
            doc["weeks"] = [
                {"date": d, "book": b, "title": t, "verses": verses(v), "sharing": s, "off": off}
                for d, b, t, v, s, off in JEDAE2_WEEKS
            ]
            doc["extras"] = JEDAE2_EXTRAS
        out[cid] = doc
    return out


def to_value(v) -> dict:
    """파이썬 값 → Firestore REST 값"""
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, dt.datetime):
        return {"timestampValue": v.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")}
    if isinstance(v, list):
        return {"arrayValue": {"values": [to_value(x) for x in v]}} if v else {"arrayValue": {}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: to_value(x) for k, x in v.items()}}}
    raise TypeError(f"지원하지 않는 값: {v!r}")


def access_token() -> str:
    path = pathlib.Path.home() / ".config" / "configstore" / "firebase-tools.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))["tokens"]["access_token"]
    except (OSError, KeyError, ValueError) as e:
        sys.exit(f"토큰을 못 읽었어요 ({path}): {e}\n먼저 `firebase login` 후 `firebase projects:list`를 실행해 주세요.")


def put(cid: str, doc: dict, token: str) -> None:
    body = json.dumps({"fields": {k: to_value(v) for k, v in doc.items()}}).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE}/courses/{cid}",
        data=body,
        method="PATCH",  # updateMask 없이 PATCH = 문서 통째로 바꾸기(없으면 만들기)
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(req) as res:
            res.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        hint = "\n토큰이 만료됐을 수 있어요: `firebase projects:list` 실행 후 다시 해 주세요." if e.code == 401 else ""
        sys.exit(f"{cid} 저장 실패 ({e.code}): {detail}{hint}")
    print(f"저장했어요: courses/{cid} ({doc['name']}, {len(doc['weeks'])}주)")


def main() -> None:
    # 윈도우 콘솔(cp949)에서도 한글·− 기호가 깨지지 않게
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="하나님앞에서 반 7개를 Firestore에 넣습니다")
    ap.add_argument("--dry-run", action="store_true", help="보내지 않고 JSON만 출력")
    ap.add_argument("--only", metavar="ID", help="이 id 반만 (예: jedae2)")
    args = ap.parse_args()

    courses = build_courses()
    if args.only:
        if args.only not in courses:
            sys.exit(f"없는 id예요: {args.only} (가능: {', '.join(courses)})")
        courses = {args.only: courses[args.only]}

    if args.dry_run:
        print(json.dumps(courses, ensure_ascii=False, indent=2))
        return

    print("안내: 토큰이 오래됐으면 먼저 `firebase projects:list`를 실행해 새로 받아 주세요.")
    token = access_token()
    now = dt.datetime.now(dt.timezone.utc)
    for cid, doc in courses.items():
        put(cid, {**doc, "updatedAt": now}, token)


if __name__ == "__main__":
    main()
