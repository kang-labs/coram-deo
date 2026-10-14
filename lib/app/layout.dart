/// 화면 크기에 따른 배치 기준을 한곳에 모읍니다.
abstract final class AppLayout {
  /// 이보다 넓으면 앱을 가운데 이 폭으로 보여줍니다 (폴드 안쪽, 태블릿).
  static const maxContentWidth = 720.0;

  /// 화면 좌우 여백
  static const sidePadding = 20.0;

  /// 카드 사이 간격
  static const cardGap = 16.0;
}
