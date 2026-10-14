import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기기에만 저장하는 설정(테마 등). `main`에서 미리 읽어 override 합니다.
/// 앱 시작 전에 읽어 두므로 화면에서는 기다리지 않고 바로 값을 쓸 수 있어요.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main()에서 sharedPreferencesProvider를 override 하세요'),
);
