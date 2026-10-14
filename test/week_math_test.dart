import 'package:coram_deo/core/dates.dart';
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/features/record/logic/part_display.dart';
import 'package:coram_deo/features/week/logic/week_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int m, int day) => DateTime.utc(2026, m, day);
  final classDates = <DateTime?>[for (var i = 0; i < 12; i++) addDays(d(9, 12), i * 7)];

  test('N주차 범위 = 수업 날짜 − 6일 ~ 수업 날짜 (6주차 10/17 → 10/11~10/17)', () {
    final r = weekRange(d(10, 17));
    expect(r.start, d(10, 11));
    expect(r.end, d(10, 17));
    expect(r.start.weekday, DateTime.sunday);
  });

  test('오늘이 속한 주차: 학기 전 1주, 끝나면 마지막 주', () {
    expect(currentWeekIndex(classDates, d(8, 1)), 0);
    expect(currentWeekIndex(classDates, d(9, 12)), 0); // 수업날은 그 주
    expect(currentWeekIndex(classDates, d(9, 13)), 1); // 다음 날은 다음 주
    expect(currentWeekIndex(classDates, d(10, 14)), 5); // 6주차
    expect(currentWeekIndex(classDates, d(10, 17)), 5);
    expect(currentWeekIndex(classDates, d(12, 25)), 11);
    expect(currentWeekIndex(const [], d(10, 14)), isNull);
  });

  test('시간이 있는 DateTime도 날짜만 봐요', () {
    expect(currentWeekIndex(classDates, DateTime(2026, 10, 17, 23, 59)), 5);
    expect(dateOnly(DateTime(2026, 10, 17, 23, 59)), d(10, 17));
  });

  test('그 주 몇 번째 날', () {
    expect(dayIndexInWeek(d(10, 17), d(10, 11)), 0);
    expect(dayIndexInWeek(d(10, 17), d(10, 17)), 6);
    expect(dayIndexInWeek(d(10, 17), d(10, 10)), isNull);
    expect(dayIndexInWeek(d(10, 17), d(10, 18)), isNull);
    expect(dayOfWeek(d(10, 17), 3), d(10, 14));
  });

  test('달이 바뀌는 주 (11/7 → 11/1~11/7)', () {
    expect(weekRange(d(11, 7)).start, d(11, 1));
    expect(dayOfWeek(d(11, 7), 6), d(11, 7));
  });

  test('아직 오지 않은 날은 체크할 수 없음', () {
    expect(isFutureDay(d(10, 15), d(10, 14)), isTrue);
    expect(isFutureDay(d(10, 14), d(10, 14)), isFalse);
    expect(weekStarted(d(10, 17), d(10, 11)), isTrue);
    expect(weekStarted(d(10, 24), d(10, 17)), isFalse);
  });

  test('새벽기도 점수: 3회 이상 0, 2회 −1, 1회 −2, 0회 −3', () {
    expect([for (var c = 0; c <= 7; c++) dawnScore(c)], [-3, -2, -1, 0, 0, 0, 0, 0]);
    expect(scoreText(-1), '−1');
    expect(scoreText(0), '0');
  });

  test('7비트 값에서 한 날 수, 켜고 끄기', () {
    expect(countDays(0), 0);
    expect(countDays(127), 7);
    expect(countDays(0x55), 4);
    expect(countDays(toggleDay(0, 6)), 1);
    expect(toggleDay(toggleDay(0, 3), 3), 0);
    expect(isDayOn(1 << 2, 2), isTrue);
  });

  test('표 글자: days 한 날 수, dawn 점수(점수 매기는 주만)', () {
    expect(dailyCellText(PartType.days, 127, scored: true), '7');
    expect(dailyCellText(PartType.days, 0, scored: true), '');
    expect(dailyCellText(PartType.days, 3, scored: false), '2');
    expect(dailyCellText(PartType.dawn, 0x3, scored: true), '−1');
    expect(dailyCellText(PartType.dawn, null, scored: true), '−3');
    expect(dailyCellText(PartType.dawn, null, scored: false), '');
    expect(dailyCellText(PartType.dawn, 0x7, scored: false), '');
    expect(dailySummary(PartType.dawn, 0x3), '2회 → −1');
    expect(dailySummary(PartType.dawn, 0x3, scored: false), '2회');
    expect(dailySummary(PartType.days, 0x1F), '5/7');
    expect(isScoredWeek(started: true, off: true), isFalse);
    expect(isScoredWeek(started: false, off: false), isFalse);
    expect(isScoredWeek(started: true, off: false), isTrue);
  });

  test('날짜 없는 주는 건너뛰고, 끝나면 날짜 있는 마지막 주', () {
    final dates = <DateTime?>[d(9, 12), d(9, 19), null];
    expect(currentWeekIndex(dates, d(12, 1)), 1);
    expect(currentWeekIndex(dates, d(9, 15)), 1);
    expect(currentWeekIndex(const [null, null], d(9, 15)), 0);
  });

  test('오늘이 실제로 들어 있는 주 (학기 밖이면 없음)', () {
    expect(weekIndexContaining(classDates, d(10, 14)), 5);
    expect(weekIndexContaining(classDates, d(9, 6)), 0); // 1주 = 9/6~9/12
    expect(weekIndexContaining(classDates, d(8, 1)), isNull);
    expect(weekIndexContaining(classDates, d(12, 25)), isNull);
  });

  test('날짜 글자 읽기·쓰기', () {
    expect(tryParseYmd('2026-09-12'), d(9, 12));
    expect(tryParseYmd('2026-02-30'), isNull);
    expect(tryParseYmd('9/12'), isNull);
    expect(ymd(d(9, 6)), '2026-09-06');
    expect(mdw(d(10, 17)), '10/17(토)');
  });
}
