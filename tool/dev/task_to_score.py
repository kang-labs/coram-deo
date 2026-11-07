"""서버의 모든 반에서 '강사 특별과제'(항목 id task) 칸 종류를 점수(score)로 바꿔요 (1.2.10).

사용법 (프로젝트 폴더에서):
    firebase projects:list                     # 먼저 한 번: 로그인 토큰을 새로 받아요 (1시간 지나면 만료)
    python tool/dev/task_to_score.py --dry-run # 바꿀 반만 보여 주기
    python tool/dev/task_to_score.py           # 바꾸기

items 필드만 고쳐요(다른 항목·칸·기록요령·반장 정보는 그대로). 이미 점수 칸인 반은 건너뛰어요.
폰에 이미 ○/X/·로 체크한 기록은 앱이 그대로 보여 줘요.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import urllib.request

from seed import BASE, access_token


def call(method: str, url: str, token: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
    )
    with urllib.request.urlopen(req) as res:
        raw = res.read()
        return json.loads(raw) if raw else {}


def fix_items(items: dict) -> bool:
    """items(arrayValue)에서 task 항목 칸을 score로. 바꿨으면 True."""
    changed = False
    for item in items.get("arrayValue", {}).get("values", []):
        f = item.get("mapValue", {}).get("fields", {})
        if f.get("id", {}).get("stringValue") != "task":
            continue
        for part in f.get("parts", {}).get("arrayValue", {}).get("values", []):
            pf = part.get("mapValue", {}).get("fields", {})
            if pf.get("type", {}).get("stringValue") == "score":
                continue
            pf["type"] = {"stringValue": "score"}
            pf.pop("dotReason", None)
            changed = True
    return changed


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    token = access_token()
    docs, page = [], ""
    while True:
        res = call("GET", f"{BASE}/courses?pageSize=100{'&pageToken=' + page if page else ''}", token)
        docs += res.get("documents", [])
        page = res.get("nextPageToken", "")
        if not page:
            break
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    count = 0
    for d in docs:
        cid = d["name"].rsplit("/", 1)[-1]
        name = d["fields"].get("name", {}).get("stringValue", "")
        items = d["fields"].get("items")
        if not items or not fix_items(items):
            print(f"건너뜀  {cid} ({name})")
            continue
        count += 1
        if args.dry_run:
            print(f"바꿀 반  {cid} ({name})")
            continue
        # 다른 사람이 그사이 고쳤으면 덮지 않게 updateTime이 같을 때만 써요
        url = (
            f"{BASE}/courses/{cid}?updateMask.fieldPaths=items&updateMask.fieldPaths=updatedAt"
            f"&currentDocument.updateTime={d['updateTime']}"
        )
        call("PATCH", url, token, {"fields": {"items": items, "updatedAt": {"timestampValue": now}}})
        print(f"바꿈    {cid} ({name})")
    print(f"{'바꿀' if args.dry_run else '바꾼'} 반 {count}개")


if __name__ == "__main__":
    main()
