import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../course/logic/course_providers.dart';
import '../../record/logic/record_providers.dart';
import 'week_math.dart';

/// 오늘 (날짜만). 앱이 다시 앞에 올 때 [TodayController.refresh]로 날짜가 바뀌었는지 확인해요.
final todayProvider = NotifierProvider<TodayController, DateTime>(TodayController.new);

class TodayController extends Notifier<DateTime> {
  @override
  DateTime build() => todayDate();

  void refresh() {
    final now = todayDate();
    if (now != state) state = now;
  }
}

/// 사용자가 고른 주차 순번(0부터). null이면 오늘이 속한 주. 반을 바꾸면 다시 null.
final pickedWeekProvider = StateProvider<int?>((ref) {
  ref.watch(selectedCourseIdProvider);
  return null;
});

/// 지금 반의 주차별 수업 날짜
final classDatesProvider = Provider<List<DateTime?>>((ref) {
  return ref.watch(currentCourseProvider.select((c) => c.valueOrNull?.classDates)) ?? const [];
});

/// 오늘이 속한 주차 순번(0부터). 일정이 없으면 null.
final currentWeekIndexProvider = Provider<int?>((ref) {
  return currentWeekIndex(ref.watch(classDatesProvider), ref.watch(todayProvider));
});

/// 이번 주 화면에 보이는 주차 순번(0부터). 일정이 없으면 null.
final shownWeekIndexProvider = Provider<int?>((ref) {
  final dates = ref.watch(classDatesProvider);
  if (dates.isEmpty) return null;
  final picked = ref.watch(pickedWeekProvider);
  return (picked ?? ref.watch(currentWeekIndexProvider) ?? 0).clamp(0, dates.length - 1);
});
