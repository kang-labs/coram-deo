import '../../../core/models/course.dart';
import '../../week/logic/week_math.dart';

/// 칸 값을 체크표 글자로 (종이 표에 적는 것과 같게).
///
/// - 고르는 칸: ○ / 지 / X, 비었으면 ''
/// - 성경·큐티·기도(days): 한 날 수. 하나도 안 했으면 ''
/// - 새벽기도(dawn): 점수(0, −1, −2, −3). 그 주가 시작 전이면 ''
String partCellText(PartType type, Object? value, {required bool started}) {
  if (!type.isDaily) return MarkValue.fromCode(value)?.symbol ?? '';
  final count = countDays(value is int ? value : 0);
  return switch (type) {
    PartType.dawn => started ? scoreText(dawnScore(count)) : '',
    _ => count == 0 ? '' : '$count',
  };
}

/// 이번 주 화면의 요일 칸 옆 합계 (성경 5/7, 새벽기도 2회 → −1)
String dailySummary(PartType type, int mask) {
  final count = countDays(mask);
  return switch (type) {
    PartType.dawn => '$count회 → ${scoreText(dawnScore(count))}',
    _ => '$count/$daysPerWeek',
  };
}
