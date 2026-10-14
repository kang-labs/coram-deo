import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/local_storage.dart';

/// 지금 고른 테마 (기기별 저장)
final themeIdProvider = NotifierProvider<ThemeController, AppThemeId>(ThemeController.new);

class ThemeController extends Notifier<AppThemeId> {
  static const storageKey = 'themeId';

  @override
  AppThemeId build() => AppThemeId.fromName(ref.watch(sharedPreferencesProvider).getString(storageKey));

  Future<void> select(AppThemeId id) async {
    if (id == state) return;
    state = id;
    await ref.read(sharedPreferencesProvider).setString(storageKey, id.name);
  }
}
