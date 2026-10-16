import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 아이폰 사파리에서 홈 화면 아이콘으로 열면 true (표준 display-mode와 따로 있어요)
@JS('navigator.standalone')
external JSBoolean? get _iosStandalone;

/// 홈 화면 아이콘이 아니라 브라우저 탭에서 열었는지.
/// 아이폰은 사파리와 홈 화면 아이콘의 저장 공간이 따로라서, 탭에서 쓰면 기록이 섞이거나 지워질 수 있어요.
bool get isBrowserTab {
  final standalone = web.window.matchMedia('(display-mode: standalone)').matches || (_iosStandalone?.toDart ?? false);
  return !standalone;
}

/// 아이폰·아이패드인지. 아이패드 사파리는 Mac으로 보이므로 터치 지원으로 구별해요.
bool get isAppleDevice {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  return RegExp('iPhone|iPad|iPod').hasMatch(ua) || (ua.contains('Macintosh') && nav.maxTouchPoints > 1);
}

/// 브라우저에 "이 사이트 저장 공간을 자동으로 지우지 말아 주세요"라고 요청해요.
/// 브라우저가 거절해도 앱은 그대로 동작해요.
Future<void> requestPersistentStorage() async {
  try {
    final storage = web.window.navigator.storage;
    if (!(await storage.persisted().toDart).toDart) await storage.persist().toDart;
  } catch (_) {}
}
