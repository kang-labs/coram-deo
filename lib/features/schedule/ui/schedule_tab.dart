import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../home/logic/home_providers.dart';
import '../../week/logic/week_providers.dart';
import 'week_details.dart';

/// 일정표 한 줄: 주차(순번) 또는 추가 줄(개강·졸업예배)
typedef ScheduleEntry = ({DateTime? date, String label, int? weekIndex, WeekInfo? week, ExtraRow? extra});

/// 주차와 추가 줄을 날짜 순서로 합칩니다. 날짜 없는 추가 줄은 맨 뒤로.
List<ScheduleEntry> scheduleEntries(Course c) {
  final entries = <ScheduleEntry>[
    for (var i = 0; i < c.weeks.length; i++)
      (date: c.weeks[i].classDate, label: '${i + 1}주', weekIndex: i, week: c.weeks[i], extra: null),
    for (final e in c.extras) (date: e.day, label: e.label, weekIndex: null, week: null, extra: e),
  ];
  // 같은 날이면 주차가 먼저. 정렬이 안정적이라 주차끼리는 원래 순서 그대로.
  int key(ScheduleEntry e) => e.date?.millisecondsSinceEpoch ?? 1 << 52;
  entries.sort((a, b) {
    final c = key(a).compareTo(key(b));
    return c != 0 ? c : (a.weekIndex == null ? 1 : 0) - (b.weekIndex == null ? 1 : 0);
  });
  return entries;
}

/// 일정표: 개강~졸업예배까지 목록. 이번 주 강조, 휴강 주 흐리게. 주차를 누르면 그 주 체크 화면으로.
class ScheduleTab extends ConsumerWidget {
  const ScheduleTab({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final entries = scheduleEntries(course);
    if (entries.isEmpty) {
      return const EmptyState(icon: Icons.event_note_rounded, title: '아직 일정표가 없어요', message: '관리자가 일정을 넣으면 여기에 보여요.');
    }
    final current = ref.watch(currentWeekIndexProvider);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 24),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = entries[i];
        final isCurrent = e.weekIndex != null && e.weekIndex == current;
        final off = e.week?.off ?? false;
        final title = e.extra?.title ?? '';
        return Opacity(
          opacity: off ? 0.5 : 1,
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            borderColor: isCurrent ? p.primary : null,
            color: off ? p.surfaceMuted : (e.extra != null ? p.accentSoft : null),
            onTap: e.weekIndex == null
                ? null
                : () {
                    ref.read(pickedWeekProvider.notifier).state = e.weekIndex;
                    ref.read(homeTabProvider.notifier).state = HomeTab.week;
                  },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(e.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (e.date != null) MutedText(mdw(e.date!), style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    if (isCurrent) const TinyBadge('이번 주'),
                    if (off) const TinyBadge('휴강', tone: Tone.neutral),
                  ],
                ),
                if (e.week != null && WeekDetails.hasAny(e.week!)) ...[
                  const SizedBox(height: 10),
                  WeekDetails(week: e.week!, dense: true),
                ],
                if (title.trim().isNotEmpty) ...[const SizedBox(height: 6), Text(title.trim())],
              ],
            ),
          ),
        );
      },
    );
  }
}
