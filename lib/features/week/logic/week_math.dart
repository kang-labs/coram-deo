/// 주차 계산 (순수 Dart). 한 주 = 그 주 수업날로 끝나는 7일.
library;

import '../../../core/dates.dart';

/// 한 주의 날 수
const daysPerWeek = 7;

/// N주차 범위: (수업 날짜 − 6일) ~ (수업 날짜)
({DateTime start, DateTime end}) weekRange(DateTime classDate) {
  final end = dateOnly(classDate);
  return (start: addDays(end, -(daysPerWeek - 1)), end: end);
}

/// 그 주 i번째 날 (0 = 첫날, 6 = 수업날)
DateTime dayOfWeek(DateTime classDate, int index) => addDays(weekRange(classDate).start, index);

/// 그 주에서 [day]가 몇 번째 날인지 (0~6). 그 주가 아니면 null.
int? dayIndexInWeek(DateTime classDate, DateTime day) {
  final i = daysBetween(weekRange(classDate).start, day);
  return i >= 0 && i < daysPerWeek ? i : null;
}

/// 오늘이 속한 주차의 순번(0부터). 학기 전이면 0(1주), 끝났으면 마지막 주.
/// 주 사이에 빈 날이 있으면 그 뒤에 오는 주를 고릅니다. [classDates]가 비면 null.
int? currentWeekIndex(List<DateTime?> classDates, DateTime today) {
  if (classDates.isEmpty) return null;
  final t = dateOnly(today);
  for (var i = 0; i < classDates.length; i++) {
    final d = classDates[i];
    if (d != null && !t.isAfter(dateOnly(d))) return i;
  }
  return classDates.length - 1;
}

/// 아직 오지 않은 날인지 (체크할 수 없음)
bool isFutureDay(DateTime day, DateTime today) => dateOnly(day).isAfter(dateOnly(today));

/// 그 주가 시작됐는지 (첫날이 오늘이거나 지났음)
bool weekStarted(DateTime classDate, DateTime today) => !isFutureDay(weekRange(classDate).start, today);

/// 7비트 체크 값에서 한 날 수 (bit0 = 그 주 첫날)
int countDays(int mask) {
  var n = 0;
  for (var i = 0; i < daysPerWeek; i++) {
    if (mask & (1 << i) != 0) n++;
  }
  return n;
}

/// [index]번째 날을 켜거나 끈 새 값
int toggleDay(int mask, int index) => (mask ^ (1 << index)) & ((1 << daysPerWeek) - 1);

bool isDayOn(int mask, int index) => mask & (1 << index) != 0;

/// 새벽기도 점수: 3회 이상 0, 2회 −1, 1회 −2, 0회 −3
int dawnScore(int count) => count >= 3 ? 0 : count - 3;

/// 점수 글자 (음수는 −, 0은 0)
String scoreText(int score) => score < 0 ? '−${-score}' : '$score';
