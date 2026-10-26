import 'package:flutter/widgets.dart';

/// 화면 크기에 따른 배치 기준을 한곳에 모읍니다.
abstract final class AppLayout {
  /// 이보다 넓으면 앱을 가운데 이 폭으로 보여줍니다 (폴드 안쪽, 태블릿).
  static const maxContentWidth = 720.0;

  /// 화면 좌우 여백
  static const sidePadding = 20.0;

  /// 카드 사이 간격
  static const cardGap = 16.0;

  /// 스크롤 목록 여백. 아래쪽에는 시스템 바(홈·뒤로가기) 높이를 더해요.
  /// 목록에 여백을 직접 주면 Flutter가 그 높이를 더해 주지 않아서, 하단 탭이 없는 화면(관리자 등)에서
  /// 마지막 줄이 시스템 바에 가려요. 하단 탭이 있는 화면은 Scaffold가 이미 빼 주므로 0이 더해져요.
  static EdgeInsets listPadding(
    BuildContext context, {
    double top = 8,
    double bottom = 24,
    double side = sidePadding,
  }) => EdgeInsets.fromLTRB(side, top, side, bottom + MediaQuery.paddingOf(context).bottom);
}
