import '../../../core/models/course.dart';
import '../../week/logic/week_math.dart';

/// 요일 칸 값을 체크표 글자로. 고르는 칸(○/X/·/지)은 MarkGlyph로 그려서 여기서 다루지 않아요.
///
/// - 성경·큐티·기도(days): 한 날 수. 하나도 안 했으면 ''
/// - 새벽기도(dawn): 점수(0, −1, −2, −3). [scored]가 아니면(휴강 주, 아직 시작 전 주) ''
String dailyCellText(PartType type, Object? value, {required bool scored}) {
  final count = countDays(value is int ? value : 0);
  return switch (type) {
    PartType.dawn => scored ? scoreText(dawnScore(count)) : '',
    _ => count == 0 ? '' : '$count',
  };
}

/// 이번 주 화면의 요일 칸 옆 합계 (성경 5/7, 새벽기도 2회 → −1). 점수를 안 매기는 주면 '2회'만.
String dailySummary(PartType type, int mask, {bool scored = true}) {
  final count = countDays(mask);
  return switch (type) {
    PartType.dawn => scored ? '$count회 → ${scoreText(dawnScore(count))}' : '$count회',
    _ => '$count/$daysPerWeek',
  };
}

/// 새벽기도 점수를 매기는 주: 시작했고 휴강이 아닌 주
bool isScoredWeek({required bool started, required bool off}) => started && !off;
