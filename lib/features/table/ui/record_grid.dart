import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../record/data/course_record.dart';
import '../../record/logic/part_display.dart';
import '../../record/logic/record_providers.dart';
import '../../record/ui/mark_glyph.dart';

/// 표 크기 묶음. 가로 화면·내보내기 그림에서는 [compact]로 줄여 써요.
enum GridDensity {
  regular,
  compact;

  GridMetrics get metrics => this == regular ? GridMetrics.regular : GridMetrics.compact;
}

/// 표를 어떻게 놓을지
enum GridLayoutMode {
  /// 첫 열은 고정, 나머지는 가로로 밀어 보기 (세로 화면)
  scroll,

  /// 화면 폭에 맞춰 줄여서 한눈에 (너무 작아지면 [scroll]로 돌아가요)
  fit,

  /// 줄이지도 밀지도 않고 원래 크기 그대로 (그림으로 저장할 때)
  full,
}

/// 표 머리·칸 크기와 글자 모양 (한곳에서 읽어요)
class GridMetrics {
  const GridMetrics._({
    required this.header,
    required this.group,
    required this.row,
    required this.firstCol,
    required this.minSingle,
    required this.minPart,
    required this.singlePad,
    required this.partPad,
    required this.glyph,
    required this.dailyFont,
    required this.titleFont,
    required this.subtitleFont,
    required this.label,
    required this.part,
  });

  final double header;
  final double group;
  final double row;
  final double firstCol;
  final double minSingle;
  final double minPart;
  final double singlePad;
  final double partPad;
  final double glyph;
  final double dailyFont;
  final double titleFont;
  final double subtitleFont;
  final TextStyle label;
  final TextStyle part;

  static const regular = GridMetrics._(
    header: 76,
    group: 44,
    row: 46,
    firstCol: 64,
    minSingle: 52,
    minPart: 44,
    singlePad: 14,
    partPad: 10,
    glyph: 18,
    dailyFont: 16,
    titleFont: 14,
    subtitleFont: 10.5,
    label: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.2),
    part: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.2),
  );

  static const compact = GridMetrics._(
    header: 58,
    group: 34,
    row: 34,
    firstCol: 52,
    minSingle: 40,
    minPart: 34,
    singlePad: 8,
    partPad: 6,
    glyph: 16,
    dailyFont: 14,
    titleFont: 13,
    subtitleFont: 9.5,
    label: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.15),
    part: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, height: 1.15),
  );
}

/// 표의 줄 하나(주차 또는 사람)의 첫 열 모양
@immutable
class RecordGridRow {
  const RecordGridRow({required this.title, this.subtitle, this.dim = false, this.highlight = false, this.onTap});

  /// 큰 글자 (예: '3주', 이름)
  final String title;

  /// 작은 글자 (예: 날짜, '휴강')
  final String? subtitle;

  /// 흐리게 (쉬는 주)
  final bool dim;

  /// 강조 바탕 (이번 주)
  final bool highlight;

  final VoidCallback? onTap;
}

/// 줄·항목·칸에 맞는 칸 내용 만들기. [row]는 [RecordGrid.rows]의 순번(0부터).
typedef GridCellBuilder = Widget Function(int row, ItemDef item, PartDef part, GridMetrics metrics);

/// 띄어쓰기에서만 줄을 바꾼 머리 글자 ('필독서 읽기' → '필독서\n읽기'). 한글은 글자 사이에서도 줄이 바뀌어서 직접 나눠요.
String gridHeaderText(String label) => label.trim().split(RegExp(r'\s+')).join('\n');

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
List<List<double>> _columnWidths(List<ItemDef> items, TextScaler scaler, TextStyle base, GridMetrics m) => [
  for (final item in items)
    if (item.parts.length == 1)
      [math.max(m.minSingle, _widestWord(item.label, base.merge(m.label), scaler) + m.singlePad)]
    else
      () {
        final parts = [
          for (final p in item.parts) math.max(m.minPart, _widestWord(p.label, base.merge(m.part), scaler) + m.partPad),
        ];
        final need = _widestWord(item.label, base.merge(m.label), scaler) + m.singlePad;
        final sum = parts.fold(0.0, (a, b) => a + b);
        // 항목 이름이 더 넓으면 칸마다 고르게 늘려요
        return sum >= need ? parts : [for (final w in parts) w + (need - sum) / parts.length];
      }(),
];

/// 종이와 같은 표: 첫 열(주차 또는 이름) + 항목 머리 + 줄마다 칸.
/// 줄 내용([rows])과 칸 내용([cellBuilder])을 받아서, 내 체크표(주차 줄)와 반 출석부(사람 줄)가 같이 써요.
class RecordGrid extends StatelessWidget {
  const RecordGrid({
    super.key,
    required this.items,
    required this.headerLabel,
    required this.rows,
    required this.cellBuilder,
    this.mode = GridLayoutMode.scroll,
    this.density = GridDensity.regular,
    this.firstColumnWidth,
    this.minFitScale = 0.55,
  });

  final List<ItemDef> items;

  /// 첫 열 머리 글자 ('주차', '이름')
  final String headerLabel;
  final List<RecordGridRow> rows;
  final GridCellBuilder cellBuilder;
  final GridLayoutMode mode;
  final GridDensity density;

  /// 첫 열 폭 (이름이 길면 넓혀요). 없으면 크기 묶음의 기본값.
  final double? firstColumnWidth;

  /// [GridLayoutMode.fit]에서 이보다 작아지면 줄이지 않고 가로로 밀게 해요
  final double minFitScale;

  @override
  Widget build(BuildContext context) {
    final m = density.metrics;
    final firstW = firstColumnWidth ?? m.firstCol;
    final widths = _columnWidths(
      items,
      MediaQuery.textScalerOf(context),
      DefaultTextStyle.of(context).style, // 화면 글꼴과 같은 글꼴로 재요
      m,
    );
    final p = context.palette;
    final border = BorderSide(color: p.line);
    BoxDecoration cellBox({Color? color}) => BoxDecoration(
      color: color,
      border: Border(right: border, bottom: border),
    );

    Widget headerCell(String text, double width, double height, TextStyle style) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: cellBox(color: p.surfaceMuted),
      // 글자 크기를 키운 폰이나 낱말이 많은 이름은 칸에 맞게 줄여요
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(gridHeaderText(text), textAlign: TextAlign.center, softWrap: false, style: style),
      ),
    );

    Widget rowWrap(RecordGridRow r, Widget child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: r.onTap,
      child: Opacity(opacity: r.dim ? 0.45 : 1, child: child),
    );
    Color rowColor(RecordGridRow r) => r.highlight ? p.primarySoft : p.surface;

    final firstColumn = Column(
      children: [
        headerCell(headerLabel, firstW, m.header, m.label),
        for (final r in rows)
          rowWrap(
            r,
            Container(
              width: firstW,
              height: m.row,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: cellBox(color: rowColor(r)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(fontSize: m.titleFont, fontWeight: FontWeight.w800),
                    ),
                    if (r.subtitle != null)
                      Text(
                        r.subtitle!,
                        style: TextStyle(fontSize: m.subtitleFont, color: p.inkSoft, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    Widget itemHeader(ItemDef item, List<double> w) {
      if (item.parts.length == 1) return headerCell(item.label, w.single, m.header, m.label);
      return Column(
        children: [
          headerCell(item.label, w.fold(0.0, (a, b) => a + b), m.group, m.label),
          Row(
            children: [
              for (var k = 0; k < item.parts.length; k++)
                headerCell(item.parts[k].label, w[k], m.header - m.group, m.part),
            ],
          ),
        ],
      );
    }

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [for (var j = 0; j < items.length; j++) itemHeader(items[j], widths[j])]),
        for (var i = 0; i < rows.length; i++)
          rowWrap(
            rows[i],
            Row(
              children: [
                for (var j = 0; j < items.length; j++)
                  for (var k = 0; k < items[j].parts.length; k++)
                    Container(
                      width: widths[j][k],
                      height: m.row,
                      alignment: Alignment.center,
                      decoration: cellBox(color: rowColor(rows[i])),
                      child: cellBuilder(i, items[j], items[j].parts[k], m),
                    ),
              ],
            ),
          ),
      ],
    );

    Widget frame(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: border, top: border),
        ),
        child: child,
      ),
    );
    Widget scrolling() => frame(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          firstColumn,
          Expanded(
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid),
          ),
        ],
      ),
    );
    Widget whole() => frame(
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [firstColumn, grid]),
    );

    switch (mode) {
      case GridLayoutMode.scroll:
        return scrolling();
      case GridLayoutMode.full:
        return whole();
      case GridLayoutMode.fit:
        final natural = firstW + widths.fold(0.0, (a, w) => a + w.fold(0.0, (x, y) => x + y)) + 1; // +1 = 왼쪽 선
        return LayoutBuilder(
          builder: (context, c) {
            if (!c.hasBoundedWidth || c.maxWidth < natural * minFitScale) return scrolling();
            return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: whole());
          },
        );
    }
  }
}

/// 표 칸 하나의 모양: 고르는 칸은 ○/X/·/지, 요일 칸은 한 날 수.
/// 사유가 있는 값은 누르면 사유를 보여 줘요 (표시는 가운데 점만).
/// 내 체크표와 반 출석부가 같은 모양이 되도록 값([entry])만 바꿔 끼워요.
class RecordCellView extends StatelessWidget {
  const RecordCellView({
    super.key,
    required this.entry,
    required this.type,
    required this.noteTitle,
    this.metrics = GridMetrics.regular,
  });

  /// 그 칸의 기록에서 바로 만들기
  factory RecordCellView.fromRecord(
    CourseRecord record, {
    required int week,
    required ItemDef item,
    required PartDef part,
    required String noteTitle,
    GridMetrics metrics = GridMetrics.regular,
  }) => RecordCellView(
    entry: record.entry(week, item.id, part.id),
    type: part.type,
    noteTitle: noteTitle,
    metrics: metrics,
  );

  final ({Object? value, String? note}) entry;
  final PartType type;

  /// 사유 창 제목 (예: '3주 사유')
  final String noteTitle;
  final GridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (type.isDaily) {
      return Text(
        dailyCellText(entry.value),
        style: TextStyle(fontSize: metrics.dailyFont, fontWeight: FontWeight.w800, color: p.ink),
      );
    }
    final mark = MarkValue.fromCode(entry.value);
    if (mark == null) return const SizedBox.shrink();
    final glyph = MarkGlyph(value: mark, color: markTone(mark).colors(p).$1, size: metrics.glyph);
    final note = entry.note;
    if (note == null) return glyph;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showInfoDialog(context, title: noteTitle, body: note),
      child: SizedBox.expand(child: Center(child: glyph)),
    );
  }
}

/// 내 기록([courseRecordProvider])에서 칸 값을 읽는 칸. 그 칸 값만 watch 해서 체크 하나에 칸 하나만 다시 그려요.
class ProviderRecordCell extends ConsumerWidget {
  const ProviderRecordCell({
    super.key,
    required this.week,
    required this.item,
    required this.part,
    this.metrics = GridMetrics.regular,
  });

  final int week;
  final ItemDef item;
  final PartDef part;
  final GridMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(courseRecordProvider.select((r) => r.entry(week, item.id, part.id)));
    return RecordCellView(entry: entry, type: part.type, noteTitle: '$week주 사유', metrics: metrics);
  }
}
