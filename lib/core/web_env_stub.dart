/// 안드로이드 앱: 브라우저가 아니므로 안내도, 저장 공간 요청도 필요 없어요.
bool get isBrowserTab => false;

/// 아이폰·아이패드 사파리인지 (홈 화면 추가 방법이 달라요)
bool get isAppleDevice => false;

Future<void> requestPersistentStorage() async {}
