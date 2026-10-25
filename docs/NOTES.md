# 기능별 메모

고치려는 기능의 절만 읽으세요. 설계는 `DESIGN.md`.

## 파일 지도

- `lib/core/models/course.dart`: `Course`, `WeekInfo`(date·book·title·verses·sharing·off), `ExtraRow`, `ItemDef`, `PartDef`, `PartType`(mark/ox/attend/days, 저장 키 = name, 예전 'dawn'은 days로 읽음), `MarkValue`(o/late/x, 저장 값 = code). 값 비교 `==` 있음.
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
- 요일 칸: 요일 + M/d, 높이 58, 오늘 굵은 테두리, 미래는 흐리고 못 누름, 옆에 합계(성경 5/7, 새벽 2/7).
- 체크표: 첫 열(주차) 고정, 나머지 가로 스크롤. 여러 칸 항목은 머리를 두 줄(항목 이름 / 칸 이름). 이번 주 줄 강조, 휴강 주 흐리게. 줄을 누르면 그 주 '이번 주'로.
  - 표 글자: ○/지/X, days = 한 날 수(0이면 빈칸).
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

## 5차 수정 (2026-10-14)

- 새벽기도 점수 없앰: `PartType.dawn`·`dawnScore`·`scoreText`·`isScoredWeek` 삭제. 새벽기도 = days(한 날 수, 'N/7'), 점수는 사용자가 계산. 서버의 'dawn'은 `PartType.fromName`이 days로 읽음. 기록요령 글은 그대로.
- 암송구절 표시: 본문 + ' (장절)'을 `Text.rich` 한 문단(장절은 2 작게·흐리게). seed는 1주 '고후 1:20'만 본문.
- 표 보기: 사유 있는 ·도 가운데 점만(모서리 표시 없앰), 누르면 사유 창.
- 사유 입력 예시: '예: 휴일'.
- seed.py: 서버에 이미 있는 반은 건너뜀('건너뛰었어요'), `--force`일 때만 덮어씀(관리자가 앱에서 고친 내용 보호).


## 웹앱 (아이폰용, 2026-10-16)

- 주소 https://coram-deo-biblekang.web.app (Firebase Hosting, `build/web`). Firebase 웹 앱 `1:188449985743:web:cb60bd56ccb1c61a7413ba`, `firebase_options.dart`의 `web`.
- 기록은 `shared_preferences` → 브라우저 localStorage(`flutter.` 접두). 서버로 가지 않음.
- `lib/core/web_env.dart`: `isBrowserTab`(홈 화면 아이콘이 아니면 true), `isAppleDevice`, `requestPersistentStorage()`(main에서 기다리지 않고 호출). 안드로이드는 stub.
- `features/install/ui/install_guide.dart`: 브라우저 탭이면 반 고르기·홈 화면 맨 위에 안내 띠(닫으면 이번 실행 동안만 숨김), 설정에 '홈 화면에 추가하는 방법'(웹만). 아이폰/안드로이드 단계가 다름.
- 아이폰은 사파리와 홈 화면 아이콘의 저장 공간이 따로라 아이콘에서 반을 처음 다시 골라야 함.
- 관리자 로그인: 웹은 `signInWithPopup`. 콘솔에서 Google 로그인 사용 설정이 되어 있어야 함(실기기 확인 안 함).
- 아이콘: 언덕 위 십자가 — 남색(#2F3E5C) 바탕, 흰(#F6F7F9) 십자가, 회청색(#5E7A99) 언덕. `python tool/dev/make_icons.py`로 안드로이드(mipmap-*/ic_launcher.png 둥근 사각형, mipmap-anydpi-v26 적응형: 전경 언덕+십자가 72/108배, 배경 @color/ic_launcher_background, monochrome은 십자가만)와 웹(Icon-*, maskable 0.8배, apple-touch 꽉 찬 사각형, favicon)을 한 번에 다시 만든다. 세로 막대는 언덕 속까지 그려 아래가 묻히게.

## 과정·기수·학기, 지난 출석부 (2026-10-17)

- 반에 `program`(Program enum id)·`cohort`·`semester` 추가(추가만, 없으면 ''/0/0). `config/app.semester` = 지금 학기. 머리글 `Course.groupTitle`(예: 25기 양육훈련, 없으면 term).
- 반 고르기: `visibleCoursesProvider` = visible && semester == 지금 학기. `groupCourses()`로 과정 순서 → 기수 큰 것 → order로 묶음.
- 학기 동기화: `selectedCourseOutdatedProvider` = 고른 반 semester < 서버 semester. `RootGate`가 listen → `SelectedCourseController.clear()`(기록 `rec.*`·사본 `snap.*`은 남음). 반 문서의 학기는 안 바뀌므로 늦게 업데이트한 폰도 풀림.
- `watchSemester`는 모르면 null: 캐시에서 문서 없음, 이 폰이 쓴 값이 서버 확인 전(hasPendingWrites). 관리자 학기 넘기기 카드는 null이면 안 보임(거꾸로 넘기기 방지), 반 고르기는 첫 값까지 로딩·null이면 visible만.
- 규칙: config/app.semester는 1씩만 올라감(처음 1). 반의 program·cohort·semester는 한 번 생기면 지우는 저장 거절(예전 앱 저장 방지).
- 사본: `currentCourseProvider`가 받을 때마다 `LocalStore.saveSnapshot`(같으면 안 씀). 지난 출석부 `pastBooksProvider`(autoDispose) = 기록 있는 반 − 지금 반, 사본 없으면 서버 반.
- 지난 출석부 보기: `PastBookScreen`이 중첩 ProviderScope로 `courseRecordProvider`(고정 기록)·`recordReadOnlyProvider`(true)·`currentWeekIndexProvider`·`todayWeekIndexProvider`(null)를 덮고 `CheckTableTab` 그대로 사용. 읽기 전용이면 주차 줄 누르기·'체크하러 가기' 없음.
- 관리자: `_SemesterCard` 다음 학기 준비하기(`prepareNextSemester`, batch) / 새 학기 시작하기(`startSemester`: semester == 새 번호인 반만 visible, 예전 앱도 새 반만 보이게). 반 메뉴 '다음 기수로 복사' = `nextSemesterCopy`(기수 +1, 날짜 비움, 12주 채움, 숨김).
- 새 반은 빈 날짜 12주로 시작. 일정표에서 1주 날짜를 고르면 날짜가 빈 뒤 주를 7일씩 채움(`_setFirstDate`).
- 서버 기존 7반 과정·기수: `python tool/dev/seed.py --set-cohorts` (25 양육, 24 제자학교, 23 제자대학1, 22 제자대학2).
- 예전 앱(v1.0.1 이하)은 학기를 몰라서 새 학기에 반이 풀리지 않음(반은 숨겨지니 목록엔 새 반만) — 업데이트하면 바로 풀림.
- 검토(opus) 반영: 학기 모를 때 0으로 믿지 않기, 늦은 업데이트, 규칙. 남은 작은 점: 지난 출석부에서 주별/표 바꾸면 메인 체크표 보기도 같이 바뀜.

## Play 스토어 준비 (2026-10-22)

- 업로드 키: `Documents/Security/Android_upload_key/coram-deo-upload.jks`(alias upload, PKCS12, ~2054), 비밀번호 `coram-deo-key.properties`(storePassword·keyPassword). git·claude_data·Project 밖.
- `android/app/build.gradle.kts`: 환경 변수 `CORAM_UPLOAD_SIGN=1`이면 업로드 키로 release 서명(키 없으면 GradleException), 아니면 debug. 평소 APK(GitHub·기기)는 debug라 기존 설치 위에 덮어 설치 가능.
- Firebase Android 앱 SHA-1: debug `f9:82:33…d2:05`, 업로드 `67:48:F2…93:BF`. Play 앱 서명 키 SHA-1은 첫 업로드 뒤 추가할 것.
- 결정(2026-10-22): 개인 계정(비공개 테스트 12명·14일), 기록 내보내기 없음, Play 정식 공개 뒤 GitHub 배포 정리, 앱 서명 키는 Google 관리(기본).
- 인앱 업데이트: `in_app_update` 5.0.0. `features/update/data/play_update.dart`(`PlayUpdate.hasUpdate`: 안드로이드만, 새 버전 있고 즉시 업데이트 가능할 때, 실패는 false) + `ui/update_prompt.dart`(`UpdatePrompt`가 `RootGate`를 감싸 앱 열 때 한 번 확인 → 공통 확인 창 '업데이트/나중에' → `performImmediateUpdate`). Play에서 받은 앱만 동작, GitHub APK·웹은 조용히 건너뜀(에뮬레이터에서 확인). 실제 업데이트 흐름은 Play 테스트 트랙에 두 버전이 올라간 뒤에만 확인 가능.

## 기록 저장·불러오기 (2026-10-22)

- 설정 > 기록 저장·불러오기 → `features/backup/ui/backup_sheet.dart`. 파일 창은 `file_picker` 13 (`BackupFiles.save`/`pick`, 테스트에서 바꿔 끼움).
- 파일 `coram-deo-backup-YYYYMMDD.json`: `{app:'coram_deo', format:1, savedAt, name, courseId, records:{id: 기록 JSON}, snapshots:{id: 반 문서}}`. `Backup.parse`는 관대하게(다른 앱 파일·깨진 파일 null, 깨진 반은 건너뜀).
- 불러오기: 파일에 든 반만 덮어씀, 다른 반은 그대로. 이름은 파일에 있을 때만, 고른 반은 폰에 없을 때만. 끝나면 selectedCourseId·myName·courseRecord·pastBooks provider 다시 읽음.
- 용도: GitHub판(debug 서명) → Play판(서명 다름, 덮어 설치 불가)으로 옮길 때, 폰 바꿀 때, 아이폰 웹 ↔ 안드로이드.

## 반장·총무 출석부, 관리자 숫자 비밀번호, 표 가로 보기 (2026-10-25)

- 처음 실행: `RootGate` → 이름이 비면 `NameScreen`(본명, 같은 이름은 A·B·C). 설정 이름은 빈 값 불가.
- 기록 올리기: 기본 Firebase 앱 익명 로그인(`memberAuthProvider`, `memberUidProvider`) → `courses/{반}/members/{uid}` {name, record, updatedAt}. `memberSyncProvider`(HomeShell watch): 3초 디바운스, prefs `sent.{반}`과 같으면 안 올림. Firebase 없으면(테스트) 건너뜀.
- 관리자: 두 번째 Firebase 앱 `admin`(main에서 초기화)에서 이메일/비밀번호 = bible4217@gmail.com + 숫자 6자리. 비밀번호는 PC에서 `python tool/dev/set_admin_pin.py`(사용자가 직접 입력, owner 토큰으로 accounts:update, emailVerified true). 구글 로그인은 '비밀번호를 잊었어요'로 작게. 관리자 쓰기는 `adminCourseRepositoryProvider`·`adminRosterRepositoryProvider`.
- 반장·총무: 반 문서 `leaders {chief, treasurer}`(공개), 코드 `courses/{반}/private/codes {code}`(관리자만). 관리자 반 메뉴 '반장·총무 정하기'(랜덤 4자리), 이름·코드 바뀌면 `leaders/*` 지움. 이름이 맞는 폰은 반마다 한 번 코드 창(prefs `leaderAsked.{반}`), 설정 '반장·총무 코드 넣기'. 인정 = `courses/{반}/leaders/{uid}` {name(띄어쓰기 뺌), code, at}를 규칙이 private 코드·이름과 비교. 새 학기 사본은 반장·총무 비움 → 권한 회수.
- 출석부: 하단 탭 `HomeTab.roster`(인정된 폰만), `RosterView`(주차 고르기, 사람 가나다순, 같은 이름은 최근 것만 `latestByName`). 관리자 반 메뉴 '출석부 보기' = 모든 반·주차 + 이미지 저장.
- 표: `features/table/ui/record_grid.dart` 공통 표(`RecordGrid`, scroll/fit/full, regular/compact), 가로(폭>높이 또는 600dp↑)는 compact fit, 세로는 밀어 보기 + '이미지로 저장'(내 표만, 이름 들어감, `gal` 2.3.3, 웹은 file_picker 내려받기). 가로일 때 제목줄 44로 낮춤.
- 규칙 시험: `firebase emulators:exec --only firestore "python tool/dev/rules_test.py"` (JAVA_HOME = Android Studio jbr). 24/24.
- 로그인 방식: 이메일/비밀번호·익명을 켬(`set_admin_pin.py --providers-only`).
