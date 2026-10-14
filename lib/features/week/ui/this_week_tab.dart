import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../record/ui/part_inputs.dart';
import '../../schedule/ui/week_details.dart';
import '../logic/week_math.dart';
import '../logic/week_providers.dart';

/// 이번 주: 주차 고르기, 이번 주 일정 카드, 항목 카드 목록
class ThisWeekTab extends ConsumerWidget {
  const ThisWeekTab({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shownWeekIndexProvider);
    final week = index == null ? null : course.weeks[index];
    final classDate = week?.classDate;
    if (index == null || week == null || classDate == null) {
      return const EmptyState(
        icon: Icons.event_note_rounded,
        title: '아직 일정표가 없어요',
        message: '관리자가 이 반의 일정을 넣으면 주마다 체크할 수 있어요.',
      );
    }
    final weekNo = index + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 24),
      children: [
        WeekSelector(index: index, count: course.weeks.length, week: week, classDate: classDate),
        if (week.off || WeekDetails.hasAny(week)) ...[
          const SizedBox(height: 12),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            color: week.off ? context.palette.surfaceMuted : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (week.off) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: TinyBadge('휴강', tone: Tone.neutral),
                  ),
                  if (WeekDetails.hasAny(week)) const SizedBox(height: 10),
                ],
                WeekDetails(week: week),
              ],
            ),
          ),
        ],
        for (final item in course.items) ...[
          const SizedBox(height: 12),
          ItemCard(key: ValueKey('$weekNo/${item.id}'), item: item, week: weekNo, classDate: classDate, off: week.off),
        ],
      ],
    );
  }
}

/// ◀ 6주차 · 10/11~10/17 ▶ (오늘 주가 아니면 '이번 주로' 버튼)
class WeekSelector extends ConsumerWidget {
  const WeekSelector({
    super.key,
    required this.index,
    required this.count,
    required this.week,
    required this.classDate,
  });

  final int index;
  final int count;
  final WeekInfo week;
  final DateTime classDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final current = ref.watch(currentWeekIndexProvider);
    final range = weekRange(classDate);
    void go(int i) => ref.read(pickedWeekProvider.notifier).state = i;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '지난 주',
              onPressed: index > 0 ? () => go(index - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${index + 1}주차', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      if (week.off) ...[const SizedBox(width: 6), const TinyBadge('휴강', tone: Tone.neutral)],
                    ],
                  ),
                  Text(
                    '${mdw(range.start)} ~ ${mdw(range.end)}',
                    style: TextStyle(fontSize: 14, color: p.inkSoft, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '다음 주',
              onPressed: index < count - 1 ? () => go(index + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 32),
            ),
          ],
        ),
        if (current != null && current != index)
          TextButton.icon(
            onPressed: () => ref.read(pickedWeekProvider.notifier).state = null,
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('이번 주로'),
          ),
      ],
    );
  }
}
