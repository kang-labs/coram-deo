import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../home/logic/home_providers.dart';
import '../../record/logic/part_display.dart';
import '../../record/logic/record_providers.dart';
import '../../week/logic/week_math.dart';
import '../../week/logic/week_providers.dart';

/// 체크표: 종이와 같은 표(주차 × 항목). 첫 열(주차)은 고정, 나머지는 가로로 밀어 봐요.
/// 주차 줄을 누르면 그 주 '이번 주' 화면으로 갑니다.
class CheckTableTab extends ConsumerWidget {
  const CheckTableTab({super.key, required this.course});

  final Course course;

  static const headerHeight = 76.0;
  static const groupHeight = 46.0;
  static const rowHeight = 46.0;
  static const weekColWidth = 64.0;
  static const singleColWidth = 58.0;
  static const multiColWidth = 46.0;

  static double colWidth(ItemDef item) => item.parts.length == 1 ? singleColWidth : multiColWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    if (course.weeks.isEmpty) {
      return const EmptyState(icon: Icons.grid_on_rounded, title: '아직 일정표가 없어요', message: '일정이 생기면 주차별 체크표가 보여요.');
    }
    final current = ref.watch(currentWeekIndexProvider);
    void open(int i) {
      ref.read(pickedWeekProvider.notifier).state = i;
      ref.read(homeTabProvider.notifier).state = HomeTab.week;
    }

    final border = BorderSide(color: p.line);
    BoxDecoration cellBox({Color? color}) => BoxDecoration(
      color: color,
      border: Border(right: border, bottom: border),
    );
    Color? rowColor(int i) => i == current ? p.primarySoft : null;

    final weekColumn = Column(
      children: [
        Container(
          width: weekColWidth,
          height: headerHeight,
          alignment: Alignment.center,
          decoration: cellBox(color: p.surfaceMuted),
          child: const Text('주차', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        for (var i = 0; i < course.weeks.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => open(i),
            child: Opacity(
              opacity: course.weeks[i].off ? 0.45 : 1,
              child: Container(
                width: weekColWidth,
                height: rowHeight,
                alignment: Alignment.center,
                decoration: cellBox(color: rowColor(i) ?? p.surface),
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
          ),
      ],
    );

    Widget headerFor(ItemDef item) {
      final single = item.parts.length == 1;
      final w = colWidth(item);
      Widget label(String text, double width, double height, {double size = 12}) => Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: cellBox(color: p.surfaceMuted),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.2),
        ),
      );
      if (single) return label(item.label, w, headerHeight);
      return Column(
        children: [
          label(item.label, w * item.parts.length, groupHeight),
          Row(children: [for (final part in item.parts) label(part.label, w, headerHeight - groupHeight, size: 10.5)]),
        ],
      );
    }

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [for (final item in course.items) headerFor(item)]),
        for (var i = 0; i < course.weeks.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => open(i),
            child: Opacity(
              opacity: course.weeks[i].off ? 0.45 : 1,
              child: Row(
                children: [
                  for (final item in course.items)
                    for (var k = 0; k < item.parts.length; k++)
                      Container(
                        width: colWidth(item),
                        height: rowHeight,
                        alignment: Alignment.center,
                        decoration: cellBox(color: rowColor(i) ?? p.surface),
                        child: _Cell(
                          week: i + 1,
                          itemId: item.id,
                          part: k,
                          type: item.parts[k].type,
                          classDate: course.weeks[i].classDate,
                        ),
                      ),
                ],
              ),
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
    required this.part,
    required this.type,
    required this.classDate,
  });

  final int week;
  final String itemId;
  final int part;
  final PartType type;
  final DateTime? classDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final value = ref.watch(courseRecordProvider.select((r) => r.value(week, itemId, part)));
    final started = classDate != null && ref.watch(todayProvider.select((t) => weekStarted(classDate!, t)));
    final text = partCellText(type, value, started: started);
    final mark = MarkValue.fromCode(value);
    final color = switch (mark) {
      MarkValue.o => p.success,
      MarkValue.late => p.warm,
      MarkValue.x => p.danger,
      null => text.startsWith('−') ? p.danger : p.ink,
    };
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
    );
  }
}
