# 하나님앞에서 (coram_deo)

교회 훈련 과정 12주 체크표 '하나님앞에서'를 폰으로 쓰는 안드로이드 앱. Flutter + Firebase(Firestore 서울, 프로젝트 `coram-deo-biblekang`).

- 전체 설계: `docs/DESIGN.md`. 새 기능 전에 해당 절을 먼저 읽을 것. 기능별 상세는 `docs/NOTES.md`.
- 패키지 `kr.biblekang.coram_deo`, 표시 이름 하나님앞에서.
- 자매 앱 `C:\Users\BB\Documents\sg_budget`(성경가계부)과 같은 스택·디자인 방식. 필요한 공통 코드는 거기서 가져와 다듬어 쓴다.

## 핵심

- 반·일정표·체크 항목·기록요령 = Firestore `courses/{id}` (누구나 읽기, 관리자만 쓰기). 개인 체크 기록 = 폰에만(`shared_preferences`), 로그인 없음. 로그인은 관리자 모드만.
- 한 주 = 그 주 수업날로 끝나는 7일.
- 체크 항목은 데이터(`items` → `parts` → `PartType` mark/attend/days/dawn) + 공통 빌더로 그린다. 항목 id는 바꾸지 않는다.

## 코드 규칙

- `lib/features/<기능>/` 아래 `data/`·`logic/`·`ui/`. flutter_riverpod 2.x(3.x 금지). 코드 생성 없이 `fromMap`/`toMap` 직접.
- 화면에서 색을 직접 쓰지 않고 `context.palette`(테마 확장)에서 읽는다. 기본 테마는 무난한 네이비(차분한 남색 + 밝은 회백색). 핑크는 기본으로 쓰지 않음(사용자 요청 2026-10-14).
- UI 문구는 한국어 해요체. 아이콘에 별·반짝이·하트 같은 장식 금지.
- 아래에서 올라오는 창·대화상자는 공통 함수 하나로.
- Firestore 구조를 바꾸면 `firestore.rules`도 같이.
- 서버 데이터 형식을 바꿔도 이미 설치된 앱이 깨지지 않게 — 새 필드는 추가만, 읽기는 관대하게(`fromMap`은 캐스트 없이 기본값, 문서 하나 실패는 건너뜀).
- git 커밋은 확인된 단위로, 메시지 끝에 Co-Authored-By 줄.

## APK

`flutter build apk --release --split-per-abi` → `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`를 SendUserFile로 보냄. release도 debug 키 서명.

공개 배포: GitHub `kang-labs/coram-deo` Releases에 이 PC에서 빌드한 통합 apk(`coram-deo-vX.Y.Z.apk`)를 `gh release create`로 올린다(README '새 버전 올리기'). CI 빌드 금지 — 서명 키가 달라 관리자 로그인·덮어 설치가 깨짐.
아이폰용 웹앱: `flutter build web --release` → `firebase deploy --only hosting` (https://coram-deo-biblekang.web.app). 웹 전용 코드는 `lib/core/web_env.dart`(조건부 import)로만.
