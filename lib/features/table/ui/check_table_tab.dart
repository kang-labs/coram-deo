import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../home/logic/home_providers.dart';
import '../../record/logic/part_display.dart';
import '../../record/logic/record_providers.dart';
import '../../record/ui/mark_glyph.dart';
import '../../week/logic/week_math.dart';
import '../../week/logic/week_providers.dart';

/// 체크표 머리·칸 크기
abstract final class _Size {
  static const header = 76.0;
  static const group = 44.0;
  static const row = 46.0;
  static const weekCol = 64.0;
  static const minSingle = 52.0;
  static const minPart = 44.0;
  static const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.2);
  static const partStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.2);
}

/// 띄어쓰기에서만 줄을 바꾼 머리 글자 ('필독서 읽기' → '필독서\n읽기'). 한글은 글자 사이에서도 줄이 바뀌어서 직접 나눠요.
String _headerText(String label) => label.trim().split(RegExp(r'\s+')).join('\n');

/// 머리 글자의 가장 긴 낱말 폭
double _widestWord(String label, TextStyle style, TextScaler scaler) {
  var w = 0.0;
  for (final word in label.trim().split(RegExp(r'\s+'))) {
    final tp = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    w = math.max(w, tp.width);
    tp.dispose();
  }
  return w;
}

/// 항목마다 칸 폭 (낱말이 잘리지 않을 만큼, 최소 폭 이상)
List<List<double>> _columnWidths(List<ItemDef> items, TextScaler scaler, TextStyle base) => [
  for (final item in items)
    if (item.parts.length == 1)
      [math.max(_Size.minSingle, _widestWord(item.label, base.merge(_Size.labelStyle), scaler) + 14)]
    else
      () {
        final parts = [
          for (final p in item.parts)
            math.max(_Size.minPart, _widestWord(p.label, base.merge(_Size.partStyle), scaler) + 10),
        ];
        final need = _widestWord(item.label, base.merge(_Size.labelStyle), scaler) + 14;
        final sum = parts.fold(0.0, (a, b) => a + b);
        // 항목 이름이 더 넓으면 칸마다 고르게 늘려요
        return sum >= need ? parts : [for (final w in parts) w + (need - sum) / parts.length];
      }(),
];

/// 체크표: 종이와 같은 표(주차 × 항목). 첫 열(주차)은 고정, 나머지는 가로로 밀어 봐요.
/// 주차 줄을 누르면 그 주 '이번 주' 화면으로 갑니다.
class CheckTableTab extends ConsumerWidget {
  const CheckTableTab({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    if (course.weeks.isEmpty) {
      return const EmptyState(icon: Icons.grid_on_rounded, title: '아직 일정표가 없어요', message: '일정이 생기면 주차별 체크표가 보여요.');
    }
    final todayIndex = ref.watch(todayWeekIndexProvider);
    final widths = _columnWidths(
      course.items,
      MediaQuery.textScalerOf(context),
      DefaultTextStyle.of(context).style, // 화면 글꼴과 같은 글꼴로 재요
    );
    void open(int i) {
      ref.read(pickedWeekProvider.notifier).state = i;
      ref.read(homeTabProvider.notifier).state = HomeTab.week;
    }

    final border = BorderSide(color: p.line);
    BoxDecoration cellBox({Color? color}) => BoxDecoration(
      color: color,
      border: Border(right: border, bottom: border),
    );
    Color rowColor(int i) => i == todayIndex ? p.primarySoft : p.surface;

    Widget headerCell(String text, double width, double height, TextStyle style) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: cellBox(color: p.surfaceMuted),
      // 글자 크기를 키운 폰이나 낱말이 많은 이름은 칸에 맞게 줄여요
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(_headerText(text), textAlign: TextAlign.center, softWrap: false, style: style),
      ),
    );

    Widget rowWrap(int i, Widget child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => open(i),
      child: Opacity(opacity: course.weeks[i].off ? 0.45 : 1, child: child),
    );

    final weekColumn = Column(
      children: [
        headerCell('주차', _Size.weekCol, _Size.header, _Size.labelStyle),
        for (var i = 0; i < course.weeks.length; i++)
          rowWrap(
            i,
            Container(
              width: _Size.weekCol,
              height: _Size.row,
              alignment: Alignment.center,
              decoration: cellBox(color: rowColor(i)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${i + 1}주', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(
                    course.weeks[i].off ? '휴강' : _md(course.weeks[i]),
                    style: TextStyle(fontSize: 10.5, color: p.inkSoft, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    Widget itemHeader(ItemDef item, List<double> w) {
      if (item.parts.length == 1) return headerCell(item.label, w.single, _Size.header, _Size.labelStyle);
      return Column(
        children: [
          headerCell(item.label, w.fold(0.0, (a, b) => a + b), _Size.group, _Size.labelStyle),
          Row(
            children: [
              for (var k = 0; k < item.parts.length; k++)
                headerCell(item.parts[k].label, w[k], _Size.header - _Size.group, _Size.partStyle),
            ],
          ),
        ],
      );
    }

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [for (var j = 0; j < course.items.length; j++) itemHeader(course.items[j], widths[j])]),
        for (var i = 0; i < course.weeks.length; i++)
          rowWrap(
            i,
            Row(
              children: [
                for (var j = 0; j < course.items.length; j++)
                  for (var k = 0; k < course.items[j].parts.length; k++)
                    Container(
                      width: widths[j][k],
                      height: _Size.row,
                      alignment: Alignment.center,
                      decoration: cellBox(color: rowColor(i)),
                      child: _Cell(
                        week: i + 1,
                        itemId: course.items[j].id,
                        partId: course.items[j].parts[k].id,
                        type: course.items[j].parts[k].type,
                        classDate: course.weeks[i].classDate,
                        off: course.weeks[i].off,
                      ),
                    ),
              ],
            ),
          ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: border, top: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                weekColumn,
                Expanded(
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const MutedText('표를 옆으로 밀어 모든 항목을 볼 수 있어요. 주차 줄을 누르면 그 주 체크 화면으로 가요.', style: TextStyle(fontSize: 13)),
      ],
    );
  }

  static String _md(WeekInfo w) {
    final d = w.classDate;
    return d == null ? '' : md(d);
  }
}

/// 표 칸 하나. 그 칸 값만 watch 해서 체크 하나에 칸 하나만 다시 그려요.
class _Cell extends ConsumerWidget {
  const _Cell({
    required this.week,
    required this.itemId,
    required this.partId,
    required this.type,
    required this.classDate,
    required this.off,
  });

  final int week;
  final String itemId;
  final String partId;
  final PartType type;
  final DateTime? classDate;
  final bool off;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final value = ref.watch(courseRecordProvider.select((r) => r.value(week, itemId, partId)));
    if (!type.isDaily) {
      final mark = MarkValue.fromCode(value);
      if (mark == null) return const SizedBox.shrink();
      return MarkGlyph(value: mark, color: markTone(mark).colors(p).$1, size: 18);
    }
    final started = classDate != null && ref.watch(todayProvider.select((t) => weekStarted(classDate!, t)));
    final text = dailyCellText(
      type,
      value,
      scored: isScoredWeek(started: started, off: off),
    );
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text.startsWith('−') ? p.danger : p.ink),
    );
  }
}
