import 'package:flutter/material.dart';

/// 아래에서 올라오는 창. 휴대폰 하단 바(제스처·버튼)와 키보드에 가리지 않게 여백을 넣고,
/// 넓은 화면(폴드 펼침, 가로)에서는 가운데에 알맞은 폭으로 띄웁니다.
///
/// [scrollable]이면 화면 높이까지 커질 수 있습니다 (스크롤은 내용 쪽에서 둡니다).
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollable = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollable,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: sheetMaxWidth),
    builder: (context) {
      final child = builder(context);
      // 키보드가 올라오면 그만큼, 아니면 하단 바만큼 띄웁니다.
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(top: false, child: child),
      );
    },
  );
}

/// 시트·대화상자의 최대 폭
const sheetMaxWidth = 560.0;
