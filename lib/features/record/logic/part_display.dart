import '../../week/logic/week_math.dart';

/// 요일 칸 값을 체크표 글자로: 한 날 수. 하나도 안 했으면 ''.
/// 고르는 칸(○/X/·/지)은 MarkGlyph로 그려서 여기서 다루지 않아요.
String dailyCellText(Object? value) {
  final count = countDays(value is int ? value : 0);
  return count == 0 ? '' : '$count';
}

/// 이번 주 화면의 요일 칸 옆 합계 (성경 5/7, 새벽기도 2/7)
String dailySummary(int mask) => '${countDays(mask)}/$daysPerWeek';
