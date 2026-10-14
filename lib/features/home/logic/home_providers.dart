import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 탭 순서. 화면 목록은 [HomeShell]이 이 순서대로 만듭니다.
enum HomeTab { week, table, schedule, settings }

/// 지금 고른 하단 탭
final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.week);
