import 'package:coram_deo/app/theme.dart';
import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/features/theme/logic/theme_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppThemeId> _themeWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c.read(themeIdProvider);
}

void main() {
  test('테마를 고른 적 없으면 기본(슬레이트), 고른 테마는 그대로', () async {
    expect(AppThemeId.fallback, AppThemeId.slate);
    expect(await _themeWith({}), AppThemeId.slate);
    expect(await _themeWith({ThemeController.storageKey: 'blossom'}), AppThemeId.blossom);
    expect(await _themeWith({ThemeController.storageKey: 'no-such'}), AppThemeId.slate);
  });

  test('모든 테마로 ThemeData를 만들 수 있고 팔레트가 들어 있음', () {
    for (final id in AppThemeId.values) {
      expect(AppTheme.of(id).extension<AppPalette>(), id.palette, reason: id.name);
    }
  });
}
