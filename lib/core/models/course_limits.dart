/// 반 문서 크기 제한. firestore.rules의 validCourse()와 같은 값이어야 해요 — 바꾸면 함께 고칩니다.
abstract final class CourseLimits {
  // 규칙이 검사하는 값
  static const name = 60;
  static const term = 60;
  static const time = 20;
  static const weeks = 60;
  static const extras = 30;
  static const items = 60;
  static const guide = 20000;

  // 앱 입력 칸 길이 (규칙은 검사하지 않지만 문서가 너무 커지지 않게)
  static const itemLabel = 40;
  static const partLabel = 20;
  static const partsPerItem = 6;
  static const weekText = 500;
  static const book = 60;
  static const versesPerWeek = 6;
  static const verseRef = 40;
  static const verseText = 1000;
  static const extraLabel = 30;
  static const extraTitle = 200;
}
