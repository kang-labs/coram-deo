# 하나님앞에서 (coram_deo)

[![Release](https://img.shields.io/github/v/release/kang-labs/coram-deo?label=Version&color=navy)](https://github.com/kang-labs/coram-deo/releases/latest)
[![Android](https://img.shields.io/badge/Android-7.0%2B-3DDC84.svg)](https://github.com/kang-labs/coram-deo/releases/latest)
[![iPhone](https://img.shields.io/badge/iPhone-웹앱-2F3E5C.svg)](https://coram-deo-biblekang.web.app)

교회 훈련 과정 12주 체크표 '하나님앞에서'를 폰으로 쓰는 안드로이드 앱이에요.
내 반을 고르면 주마다 체크할 항목이 나오고, 기록은 내 폰에 저장되고, 그 반 반장·총무와 관리자가 출석부로 볼 수 있어요. 회원가입이나 구글 계정은 필요 없어요.

## 📱 다운로드

### 안드로이드

[**최신 버전 내려받기 (GitHub Releases)**](https://github.com/kang-labs/coram-deo/releases/latest) 페이지 아래쪽 **Assets**에서 `coram-deo-v○.○.○.apk`를 누르세요.

- 휴대폰 브라우저에서 apk 파일을 내려받아 열어요.
- "출처를 알 수 없는 앱 설치" 허용을 물으면 허용해요. Play 스토어 밖에서 받은 앱이라 뜨는 안내예요.
- 홈 화면에 **하나님앞에서** 아이콘이 생겨요.
- 새 버전도 같은 방법으로 받아 덮어 설치하면 체크 기록이 그대로 남아요.

### 아이폰 (웹앱)

아이폰은 파일로 설치할 수 없어서 웹앱으로 써요. 기록은 앱과 똑같이 그 폰에 저장돼요.

1. 아이폰 **사파리**에서 **https://coram-deo-biblekang.web.app** 을 열어요. (카카오톡 안에서 열렸다면 ⋯ → "Safari로 열기")
2. 공유 버튼 → **홈 화면에 추가** → 추가.
3. 홈 화면에 생긴 **하나님앞에서** 아이콘으로만 열어요.

- 사파리 탭에서 쓰면 7일 동안 안 쓸 때 기록이 지워질 수 있고, 사파리와 홈 화면 아이콘은 기록이 따로예요. 꼭 아이콘으로 써 주세요.
- 설정 > 사파리 > "방문 기록 및 웹사이트 데이터 지우기"를 하면 기록도 지워져요.
- 안드로이드도 크롬에서 같은 주소를 열고 ⋮ → "홈 화면에 추가"로 쓸 수 있어요.

---

아래는 개발용 안내예요. Flutter + Firebase(Firestore, 프로젝트 `coram-deo-biblekang`). 설계는 `docs/DESIGN.md`, 기능별 메모는 `docs/NOTES.md`.

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

release도 평소에는 debug 키로 서명해요(`android/app/build.gradle.kts`). Play 스토어용 AAB만 업로드 키로 서명해요(아래).

### 새 버전 올리기 (GitHub Releases)

관리자 구글 로그인이 이 PC debug 키의 SHA-1에 묶여 있어서, GitHub Actions가 아니라 **이 PC에서 빌드해서** 올려요(다른 키로 서명하면 로그인도, 덮어 설치도 안 돼요).

```bash
# 1) pubspec.yaml의 version을 올린다 (예: 1.0.1+2) → 커밋·push
flutter build apk --release                  # 모든 폰에서 되는 통합 apk
cp build/app/outputs/flutter-apk/app-release.apk coram-deo-v1.0.1.apk
gh release create v1.0.1 coram-deo-v1.0.1.apk --title "하나님앞에서 v1.0.1" --generate-notes
```

GitHub는 첨부 파일 이름의 한글을 지우므로 파일 이름은 영문으로 해요.

### Play 스토어용 AAB (업로드 키)

업로드 키는 git 밖 `Documents/Security/Android_upload_key/`에 있어요(`coram-deo-upload.jks`, 비밀번호는 `coram-deo-key.properties`). 환경 변수를 켤 때만 이 키로 서명하고, 키가 없으면 빌드가 멈춰요.

```powershell
$env:CORAM_UPLOAD_SIGN="1"; flutter build appbundle --release; Remove-Item Env:CORAM_UPLOAD_SIGN
# → build/app/outputs/bundle/release/app-release.aab
```

- 업로드 키 SHA-1 `67:48:F2:AE:…:93:BF`는 Firebase에 등록했어요. Play 앱 서명 키 SHA-1도 첫 업로드 뒤 Play Console(앱 무결성)에서 복사해 Firebase에 더해야 관리자 로그인이 돼요.

### 웹앱 올리기 (Firebase Hosting)

```bash
flutter build web --release
firebase deploy --only hosting               # → https://coram-deo-biblekang.web.app
```

시작 파일(index.html 등)은 캐시하지 않게 해 두어서, 다시 열면 새 버전이 받아져요.

## 반 데이터 넣기 (seed)

처음 등록할 반 7개(설계서 §2)와 제자대학2학기 일정표(§4)를 넣어요. 이미 있는 반은 건너뛰고, `--force`면 **통째로 덮어써요**(앱에서 고친 내용이 사라져요).

```bash
firebase projects:list                       # 먼저: 로그인 토큰 새로 받기 (1시간이면 만료)
python tool/dev/seed.py --dry-run            # 보낼 내용만 보기
python tool/dev/seed.py                      # 없는 반만
python tool/dev/seed.py --force              # 있는 반도 덮어쓰기
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
