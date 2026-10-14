# 기능별 메모

고치려는 기능의 절만 읽으세요. 설계는 `DESIGN.md`.

## 파일 지도

- `lib/core/models/course.dart`: `Course`, `WeekInfo`(date·book·title·verses·sharing·off), `ExtraRow`, `ItemDef`, `PartDef`, `PartType`(mark/attend/days/dawn, 저장 키 = name), `MarkValue`(o/late/x, 저장 값 = code). 값 비교 `==` 있음.
- `lib/core/models/course_defaults.dart`: 기본 항목 15개(`defaultItems`), 기록요령(`defaultGuide`), `newItemId`, `fillWeeks`. **`tool/dev/seed.py`와 같아야 함**(테스트가 확인).
- `lib/core/dates.dart`: 날짜만(UTC 자정) 도우미 — `tryParseYmd`, `ymd`, `md`, `mdw`, `addDays`.
- `lib/features/week/logic/week_math.dart`: 주차 계산(순수 Dart). `week_providers.dart`: `todayProvider`(앱 다시 열 때 갱신), `pickedWeekProvider`(고른 주, null = 오늘 주), `shownWeekIndexProvider`.
- `lib/features/record/`: 폰 기록. `data/course_record.dart`(JSON), `data/local_store.dart`(prefs 키), `logic/record_providers.dart`(고른 반·내 이름·기록), `logic/part_display.dart`(표 글자·합계), `ui/part_inputs.dart`(항목 카드 + 칸 종류별 공통 입력).
- `lib/features/course/`: Firestore `courses` 저장소·provider, 반 고르기 화면/시트.
- `lib/features/home/ui/home_shell.dart`: 하단 탭 4개(`HomeTab` → `_tabs` 표 하나로 정의).
- `lib/features/{week,table,schedule,settings}/ui/`: 네 탭. `schedule/ui/week_details.dart`는 이번 주 카드와 일정표가 같이 씀.
- `lib/features/admin/`: 구글 로그인, 반 목록, 반 편집.
- `lib/app/`: 테마(성경가계부에서 가져와 줄임), 공통 위젯, `showAppSheet`, 대화상자.

## 주차 계산

- 한 주 = 그 주 수업날로 끝나는 7일: `weekRange(date)` = date−6 ~ date.
- 오늘 주 = 수업 날짜가 오늘 이후(같은 날 포함)인 첫 주. 학기 전이면 1주, 끝났으면 마지막 주. 주 사이에 빈 날이 있으면 그 뒤 주.
- 날짜는 전부 `DateTime.utc(y, m, d)`로 맞춰서 시간대·시각 영향 없음.
- 아직 오지 않은 날은 요일 칸을 누를 수 없음. 고르는 칸(○/X)은 그 주가 시작한 뒤부터 고를 수 있음(예습 등은 주 안에서 미리 체크 가능).

## 기록 (폰에만)

- 키: `courseId`, `name`, `rec.{courseId}` = `{"6": {"attend": {"att": "o"}, "bible": {"main": 127}}}`. 주차(1부터) → 항목 id → 칸 id.
- 칸 id(`PartDef.id`): 기본 칸은 att/review/pulpit, 칸 하나면 main, 새 칸은 `p_<시각36진법>`. 서버 문서에 id가 없으면 `legacyPartId`(기본 항목의 같은 순번 칸 id, 아니면 p0·p1…)로 채움. 폰의 v1 목록 형식도 같은 규칙으로 옮겨 읽음.
- 빈 값(null·0)만 남은 항목·주차는 지워서 JSON을 작게 유지. 깨진 JSON은 빈 기록으로 읽음.
- 체크할 때마다 바로 저장(SharedPreferences는 메모리 값을 먼저 바꾸고 디스크는 뒤에서 씀).
- 화면은 칸 하나만 `select`로 watch → 체크 하나에 그 칸만 다시 그림(체크표 칸도 같음).
- 주의: 기록은 **주차 순번**으로 이어짐. 관리자가 일정 중간에 주를 넣거나 빼면 그 뒤 기록이 한 주씩 밀려 보임(편집은 끝에서만 더하기·빼기). 날짜만 바꾸는 건 괜찮음. 항목·칸 id는 바뀌지 않음.

## 화면

- 이번 주: ◀ N주차 · 날짜 범위 ▶, 오늘 주가 아니면 '이번 주로'. 일정 카드(교재·훈련 내용·암송구절·나눔, 휴강 배지). 항목 카드: 칸이 하나면 항목 이름을 제목으로, 여러 칸이면 항목 이름 아래 칸마다 한 줄.
- 요일 칸: 요일 + M/d, 높이 58, 오늘 굵은 테두리, 미래는 흐리고 못 누름, 옆에 합계(성경 5/7, 새벽 2회 → −1).
- 체크표: 첫 열(주차) 고정, 나머지 가로 스크롤. 여러 칸 항목은 머리를 두 줄(항목 이름 / 칸 이름). 이번 주 줄 강조, 휴강 주 흐리게. 줄을 누르면 그 주 '이번 주'로.
  - 표 글자: ○/지/X, days = 한 날 수(0이면 빈칸), dawn = 점수(그 주 시작 전이면 빈칸, 시작했으면 체크 없을 때 −3).
- 일정표: 주차 + 추가 줄(개강·졸업예배)을 날짜순으로. 주차를 누르면 그 주로.
- 설정: 반 바꾸기(시트), 내 이름(앱바에 기수·학기 · 이름으로 표시), 기록요령, 테마(5가지, 기본 블러썸), 관리자 모드.
- 앱바: 반 이름 + '기수·학기 · 내 이름'(모든 탭 공통).

## 관리자 모드

- `adminEmails`(`lib/core/admin.dart`) + 이메일 확인됨일 때만 반 목록. 규칙도 같은 조건.
- 반 목록: 추가(기본 항목·기록요령, 숨김으로 시작), 새 학기로 복사(새 id, 숨김, 학기 글에 '(새 학기)'), 숨기기/보이기, 삭제(확인).
- 반 편집(탭 4개, 저장을 눌러야 서버에 올라감, 안 저장하고 나가면 확인):
  - 기본 정보: 이름, 기수·학기, 요일, 시간, 순서, 보이기.
  - 일정표: 1주 날짜 + 주 수 → '7일씩 채우기'(이미 적은 내용은 순서대로 유지). 1주 날짜 요일이 수업 요일과 다르면 경고. 주마다 날짜·휴강·교재·훈련 내용·암송구절·나눔. 추가 줄.
  - 체크 항목: 끌어서 순서, 이름, 칸 추가·삭제·종류. 새 항목 id = `item_<시각36진법>`. 기존 id는 안 바뀜. 칸 이름이 비면 항목 이름으로 저장.
  - 기록요령: 글, 기본 글로 되돌리기.
- 입력 칸은 `TextFormField(initialValue)` + 키. 목록을 통째로 바꿀 때(자동 채우기, 줄 삭제)는 `_gen`을 올려 칸을 새로 만듦.

## Firestore

- `courses/{id}`만 씀. 반 목록은 `orderBy('order')` 한 번에 받아 숨김은 앱에서 거름(복합 색인 필요 없음).
- 저장은 `set`(통째로) + `updatedAt` 서버 시각. 오프라인 캐시는 안드로이드 기본값(켜짐).
- 규칙(`firestore.rules`): 읽기 누구나, 쓰기 `isAdmin()` + 필드 타입·크기 가볍게 검사.

## 아직 안 한 것 (설계서 §8)

- 기록 백업·복원, 매일 저녁 알림, 체크표 이미지 공유, 앱 아이콘(지금은 Flutter 기본 아이콘).

## 2차 수정 (2026-10-14)

- 칸 종류: mark ○/X/·(dot), ox ○/X(구절암송), attend ○/X/지각(표는 '지'). 표시는 `record/ui/mark_glyph.dart`(직접 그린 ○·X·점, 지각은 글자) — 버튼·체크표 공통. 고른 버튼은 옅은 색 바탕 + 진한 표시, 안 고른 버튼은 흐린 표시.
- 기본 테마 = 슬레이트(네이비 #2F3E5C + #F6F7F9). 테마를 고른 적 없으면(저장값 없음) 슬레이트, 블러썸 등은 고를 수 있음. 카드는 옅은 테두리.
- 오늘: 자정 타이머 + 앱 다시 열 때 확인, 날짜가 바뀌면 고른 주차 초기화. '이번 주' 배지·강조는 오늘이 그 주 범위 안일 때만(`todayWeekIndexProvider`), 자동으로 고르는 주는 `currentWeekIndexProvider`(학기 전 1주, 끝나면 날짜 있는 마지막 주).
- 새벽기도 점수는 시작했고 휴강이 아닌 주만(아니면 표 빈칸, 카드엔 'N회'만).
- 체크표 칸 폭: 머리 글자를 띄어쓰기에서만 줄 바꾸고, 가장 긴 낱말이 들어가게 화면 글꼴로 재서 정함.
- 주 날짜 범위: 한 줄에 안 들어가면 '10/11~10/17'로 짧게(보통 폰 폭에서는 짧은 쪽).
- 관리자: 저장 검사 `admin/logic/course_validation.dart`(규칙과 같은 제한 `core/models/course_limits.dart`, 주 날짜 7일 이상 간격, id 겹침). 서버 확인은 5초까지만 기다리고(`CourseRepository.confirmedWithin`) 안 오면 '인터넷이 연결되면 올라가요'. 새 학기 복사는 날짜를 비움.

## 3차 수정 (2026-10-14)

- · 사유: `CourseRecord`에 `{"v","note"}`로 저장, `value()`는 값만, `note()`·`entry()`. `MarkValue.needsNote`(·)면 고를 때 `showTextInputDialog`(취소 = 그대로). 다른 값으로 바꾸면 사유 지움. 이번 주 카드는 줄 아래 '사유: …'(눌러서 고치기), 주별 보기는 · 옆 글자, 표는 작은 점 + 누르면 사유 창.
- 암송구절: `WeekInfo.verses` = `List<Verse{ref, text}>`. 서버의 예전 여러 줄 글은 줄마다 장절로 읽음(`Verse.listFrom`). 화면은 본문 크게 + 장절 작게(`schedule/ui/week_details.dart`). 관리자 편집은 구절마다 장절·본문(여러 줄), 추가·삭제(주마다 6개), 저장 때 빈 구절 뺌. seed는 장절만(본문 비움, 저작권).
- 나눔은 한 줄로 seed ('제자삼는 세계비전 part1 1,2장', 'part2 1,2장').
- 체크표 탭: `table/logic/table_view_provider.dart`(prefs `tableView`, 기본 주별). 주별 = `table/ui/week_pages_view.dart`(PageView, 오늘 주부터, 줄 높이 60 이상, 값 26sp, 값 칸은 줄 폭의 64%까지), 값 하나 = `table/ui/big_value.dart`(칸 값만 watch). 표 = 예전 표(`_GridView`).
- `SelectPills` 알약은 글자 폭만큼(Container alignment 대신 Center widthFactor 1 — Wrap 안에서 한 줄을 다 차지하던 것).
- 주 날짜 범위 글자는 `week/ui/week_range_text.dart`(이번 주·주별 보기 공통).

## 4차 수정 (2026-10-14)

- `PartDef.dotReason`(기본 true, true면 저장에서 뺌, 없으면 true로 읽음). false면 ·를 사유 창 없이 바로 고르고 사유 줄도 숨김(`PartDef.needsNote`). 기본·seed: 강사 특별과제만 false. 관리자 항목 편집에서 mark 칸에만 '· 고를 때 사유 받기' 스위치.
- 서버 읽기 관대하게(`course.dart`의 `_str`·`_int`·`_bool`·`_maps`: 타입이 다르면 기본값, 모양 다른 항목 건너뜀), 반 문서 하나 실패는 `CourseRepository.parseCourse`가 null → 목록에서 빠짐. 새 필드는 추가만.
- 이번 주 카드: 본문 없는 암송구절끼리는 줄 간격 없이(훈련 내용 줄처럼), 본문 있는 구절 사이만 띄움.
- 주별 보기 여러 칸 항목: '칸 이름 + 값' 작은 줄을 오른쪽 정렬로 쌓음. ○·X·· ·지·– 는 모두 36 상자 안(줄마다 위치 같음), ·는 점을 키움(지름 = 크기의 36%), 사유는 값 아래 작은 글씨 최대 두 줄.

