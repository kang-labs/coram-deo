# 하나님앞에서 (coram_deo)

교회 훈련 과정 12주 체크표 '하나님앞에서'를 폰으로 쓰는 안드로이드 앱이에요.
Flutter + Firebase(Firestore, 프로젝트 `coram-deo-biblekang`). 설계는 `docs/DESIGN.md`, 기능별 메모는 `docs/NOTES.md`.

## 실행

```bash
flutter pub get
flutter run                 # 연결된 폰·에뮬레이터
flutter analyze && flutter test
```

- 테스트는 Firebase 없이 돌아가요(가짜 반 데이터, provider 덮어쓰기).
- `test/seed_sync_test.dart`는 `python`이 있으면 `tool/dev/seed.py`의 기본 항목·기록요령이 앱과 같은지 확인해요.

## APK

```bash
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (갤럭시용)
```

release도 지금은 debug 키로 서명해요(`android/app/build.gradle.kts`).

## 반 데이터 넣기 (seed)

처음 등록할 반 7개(설계서 §2)와 제자대학2학기 일정표(§4)를 넣어요. 같은 id 문서는 **통째로 덮어써요.**

```bash
firebase projects:list                       # 먼저: 로그인 토큰 새로 받기 (1시간이면 만료)
python tool/dev/seed.py --dry-run            # 보낼 내용만 보기
python tool/dev/seed.py                      # 7개 모두
python tool/dev/seed.py --only jedae2        # 한 반만
```

반 id: `yangyuk_a`, `yangyuk_bc`, `jejahak_a`, `jejahak_b`, `jedae1_a`, `jedae1_b`, `jedae2`.

## 보안 규칙 배포

```bash
firebase deploy --only firestore:rules      # .firebaserc 기본 프로젝트 = coram-deo-biblekang
```

- `courses`: 누구나 읽기, 쓰기는 관리자 이메일(구글 로그인, 이메일 확인됨)만.
- 관리자 목록은 두 곳에 있어요: `firestore.rules`의 `isAdmin()`과 `lib/core/admin.dart`. 함께 고쳐요.

## 관리자 구글 로그인 준비 (한 번)

지금 `android/app/google-services.json`에 OAuth 클라이언트가 비어 있어서, 아래를 해야 관리자 로그인이 돼요.

1. Firebase 콘솔 > Authentication > 로그인 방법 > Google 사용 설정
2. 프로젝트 설정 > 안드로이드 앱(`kr.biblekang.coram_deo`)에 debug 키 SHA-1 추가
   (`cd android && ./gradlew signingReport` 또는 `keytool -list -v -keystore ~/.android/debug.keystore -storepass android`)
3. `flutterfire configure` 또는 콘솔에서 새 `google-services.json` 받아 바꾸기
