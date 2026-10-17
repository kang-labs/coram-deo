/// 훈련 과정. 한 기수가 양육훈련 → 제자학교 → 제자대학1학기 → 제자대학2학기 순서로 올라가요.
/// [id]는 서버(`courses.program`)에 저장하는 값이라 바꾸지 않아요.
enum Program {
  yangyuk('yangyuk', '양육훈련'),
  jejahak('jejahak', '제자학교'),
  jedae1('jedae1', '제자대학1학기'),
  jedae2('jedae2', '제자대학2학기');

  const Program(this.id, this.label);

  final String id;
  final String label;

  /// 서버 값 → 과정. 모르는 값(빈 값, 앞으로 생길 과정)이면 null.
  static Program? fromId(Object? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}
