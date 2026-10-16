/// 웹으로 열었을 때만 필요한 브라우저 정보. 안드로이드 앱에서는 모두 '해당 없음' 값이에요.
library;

export 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart';
