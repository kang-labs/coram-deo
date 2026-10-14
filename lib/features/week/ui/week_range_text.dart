import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../logic/week_math.dart';

/// 주 날짜 범위 한 줄. 넓으면 '10/11(일) ~ 10/17(토)', 좁으면 '10/11~10/17'로 줄여서 두 줄로 꺾이지 않게.
class WeekRangeText extends StatelessWidget {
  const WeekRangeText({super.key, required this.classDate, required this.style});

  final DateTime? classDate;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final d = classDate;
    if (d == null) return Text('날짜 미정', style: style);
    final r = weekRange(d);
    final full = '${mdw(r.start)} ~ ${mdw(r.end)}';
    final short = '${md(r.start)}~${md(r.end)}';
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          // 화면 글꼴과 같은 글꼴로 재요
          text: TextSpan(text: full, style: DefaultTextStyle.of(context).style.merge(style)),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fits = tp.width <= c.maxWidth;
        tp.dispose();
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(fits ? full : short, maxLines: 1, softWrap: false, style: style),
        );
      },
    );
  }
}
