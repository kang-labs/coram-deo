import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../course/logic/course_providers.dart';
import '../../record/logic/record_providers.dart';
import 'week_math.dart';

/// 오늘 (날짜만). 자정이 지나면 타이머로, 앱이 다시 앞에 올 때는 [TodayController.refresh]로 바뀌어요.
final todayProvider = NotifierProvider<TodayController, DateTime>(TodayController.new);

class TodayController extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleMidnight();
    return todayDate();
  }

  void refresh() {
    final now = todayDate();
    if (now != state) state = now;
    _scheduleMidnight();
  }

  /// 다음 자정(기기 시간) 조금 뒤에 날짜를 다시 확인해요.
  void _scheduleMidnight() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _timer = Timer(next.difference(now), refresh);
  }
}

/// 사용자가 고른 주차 순번(0부터). null이면 오늘 주. 반을 바꾸거나 날짜가 바뀌면 다시 null.
final pickedWeekProvider = StateProvider<int?>((ref) {
  ref.watch(selectedCourseIdProvider);
  ref.watch(todayProvider);
  return null;
});

/// 주차별 수업 날짜 목록. 내용으로 비교해서, 반 문서가 다시 와도 날짜가 같으면 아래 provider가 다시 계산하지 않아요.
@immutable
class ClassDates {
  const ClassDates(this.dates);

  final List<DateTime?> dates;

  static const empty = ClassDates([]);

  @override
  bool operator ==(Object other) => other is ClassDates && listEquals(other.dates, dates);

  @override
  int get hashCode => Object.hashAll(dates);
}

/// 지금 반의 주차별 수업 날짜
final classDatesProvider = Provider<ClassDates>((ref) {
  final dates = ref.watch(currentCourseProvider.select((c) => c.valueOrNull?.classDates));
  return dates == null ? ClassDates.empty : ClassDates(dates);
});

/// 오늘 기준으로 고르는 주차 순번(0부터): 학기 전 1주, 끝나면 날짜 있는 마지막 주. 일정이 없으면 null.
final currentWeekIndexProvider = Provider<int?>((ref) {
  return currentWeekIndex(ref.watch(classDatesProvider).dates, ref.watch(todayProvider));
});

/// 오늘이 실제로 들어 있는 주차 순번 ('이번 주' 배지·강조용). 학기 밖이면 null.
final todayWeekIndexProvider = Provider<int?>((ref) {
  return weekIndexContaining(ref.watch(classDatesProvider).dates, ref.watch(todayProvider));
});

/// 이번 주 화면에 보이는 주차 순번(0부터). 일정이 없으면 null.
final shownWeekIndexProvider = Provider<int?>((ref) {
  final count = ref.watch(classDatesProvider).dates.length;
  if (count == 0) return null;
  final picked = ref.watch(pickedWeekProvider);
  return (picked ?? ref.watch(currentWeekIndexProvider) ?? 0).clamp(0, count - 1);
});
