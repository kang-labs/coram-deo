import '../../../core/models/course.dart';
import '../../week/logic/week_math.dart';

/// 요일 칸 값을 체크표 글자로: 한 날 수. 하나도 안 했으면 시작된 주는 '0', 아직 안 온 주는 ''.
/// 고르는 칸(○/X/·/지)은 MarkGlyph로 그려서 여기서 다루지 않아요.
String dailyCellText(Object? value, {bool started = false}) {
  final count = countDays(value is int ? value : 0);
  return count == 0 && !started ? '' : '$count';
}

/// 표에서 빈 요일 칸을 0으로 채울 주인지: 휴강이 아니고 날짜가 있고 그 주가 시작됐을 때
bool weekCountsZero(WeekInfo w, DateTime today) {
  final d = w.classDate;
  return !w.off && d != null && weekStarted(d, today);
}

/// 점수 칸 값을 표 글자로: +5. 숫자가 아니거나 0이면 '' (예전에 ○/X/·로 체크한 값은 [MarkValue]로 따로 그려요).
String scoreText(Object? value) => value is int && value > 0 ? '+$value' : '';

/// 점수 최대 자리 수
const scoreMaxDigits = 3;

/// 이번 주 화면의 요일 칸 옆 합계 (성경 5/7, 새벽기도 2/7)
String dailySummary(int mask) => '${countDays(mask)}/$daysPerWeek';
