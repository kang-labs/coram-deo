import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../../core/models/course_limits.dart';

/// 저장 전 반 검사. 문제가 없으면 null, 있으면 관리자에게 보여 줄 안내 글.
/// 서버 규칙(firestore.rules)과 같은 제한을 먼저 확인해서, 저장이 서버에서 거절되지 않게 합니다.
String? validateCourse(Course c) {
  final name = c.name.trim();
  if (name.isEmpty) return '반 이름을 적어 주세요.';
  if (name.length > CourseLimits.name) return '반 이름은 ${CourseLimits.name}자까지 쓸 수 있어요.';
  if (c.term.trim().length > CourseLimits.term) return '기수·학기는 ${CourseLimits.term}자까지 쓸 수 있어요.';
  if (c.time.trim().length > CourseLimits.time) return '수업 시간은 ${CourseLimits.time}자까지 쓸 수 있어요.';
  if (c.guide.length > CourseLimits.guide) return '기록요령은 ${CourseLimits.guide}자까지 쓸 수 있어요.';
  if (c.weeks.length > CourseLimits.weeks) return '일정은 ${CourseLimits.weeks}주까지 넣을 수 있어요.';
  if (c.extras.length > CourseLimits.extras) return '추가 줄은 ${CourseLimits.extras}개까지 넣을 수 있어요.';

  // 주 날짜: 모두 있어야 하고, 앞 주보다 7일 이상 뒤
  DateTime? prev;
  for (var i = 0; i < c.weeks.length; i++) {
    final d = c.weeks[i].classDate;
    if (d == null) return '${i + 1}주 날짜를 정해 주세요.';
    if (prev != null && daysBetween(prev, d) < 7) {
      return '${i + 1}주 날짜(${mdw(d)})는 $i주(${mdw(prev)})보다 7일 이상 뒤여야 해요.';
    }
    prev = d;
  }

  if (c.items.isEmpty) return '체크 항목이 하나 이상 있어야 해요.';
  if (c.items.length > CourseLimits.items) return '체크 항목은 ${CourseLimits.items}개까지 넣을 수 있어요.';
  final itemIds = <String>{};
  for (final item in c.items) {
    final label = item.label.trim();
    if (label.isEmpty) return '이름 없는 체크 항목이 있어요.';
    if (item.id.isEmpty || !itemIds.add(item.id)) return '$label 항목의 id가 겹쳐요. 항목을 지우고 다시 추가해 주세요.';
    if (item.parts.isEmpty) return '$label에 칸이 하나 이상 있어야 해요.';
    final partIds = <String>{};
    for (final p in item.parts) {
      if (p.id.isEmpty || !partIds.add(p.id)) return '$label의 칸 id가 겹쳐요. 칸을 지우고 다시 추가해 주세요.';
    }
  }
  return null;
}
