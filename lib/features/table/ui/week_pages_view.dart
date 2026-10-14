import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../home/logic/home_providers.dart';
import '../../week/logic/week_providers.dart';
import '../../week/ui/week_range_text.dart';
import 'big_value.dart';

/// 체크표 '주별' 보기: 한 주를 한 쪽에 크게. 옆으로 밀어 다른 주, 처음엔 오늘 주.
/// 출석 확인 때 반장에게 보여 주기 좋게 줄을 넉넉히, 값은 크게 그려요.
class WeekPagesView extends ConsumerStatefulWidget {
  const WeekPagesView({super.key, required this.course});

  final Course course;

  @override
  ConsumerState<WeekPagesView> createState() => _WeekPagesViewState();
}

class _WeekPagesViewState extends ConsumerState<WeekPagesView> {
  late int _page = (ref.read(currentWeekIndexProvider) ?? 0).clamp(0, widget.course.weeks.length - 1);
  late final _controller = PageController(initialPage: _page);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) =>
      _controller.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);

  void _edit(int i) {
    ref.read(pickedWeekProvider.notifier).state = i;
    ref.read(homeTabProvider.notifier).state = HomeTab.week;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final weeks = widget.course.weeks;
    final page = _page.clamp(0, weeks.length - 1);
    final week = weeks[page];
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '지난 주',
              onPressed: page > 0 ? () => _go(page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${page + 1}주차', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      if (week.off) ...[const SizedBox(width: 6), const TinyBadge('휴강', tone: Tone.neutral)],
                    ],
                  ),
                  WeekRangeText(
                    classDate: week.classDate,
                    style: TextStyle(fontSize: 14, color: p.inkSoft, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '다음 주',
              onPressed: page < weeks.length - 1 ? () => _go(page + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 32),
            ),
          ],
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: weeks.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _WeekPage(course: widget.course, index: i, onEdit: () => _edit(i)),
          ),
        ),
      ],
    );
  }
}

/// 한 주 쪽: 휴강 안내, 항목마다 한 줄(이름 왼쪽, 값 오른쪽 크게), 맨 아래 '이 주 체크하기'
class _WeekPage extends StatelessWidget {
  const _WeekPage({required this.course, required this.index, required this.onEdit});

  final Course course;
  final int index;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final week = course.weeks[index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 4, AppLayout.sidePadding, 24),
      children: [
        if (week.off) ...[
          SoftCard(
            color: p.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.event_busy_rounded, color: p.inkSoft),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('휴강 주예요', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: LayoutBuilder(
            builder: (context, c) => Column(
              children: [
                for (var j = 0; j < course.items.length; j++) ...[
                  if (j > 0) const Divider(),
                  _ItemRow(item: course.items[j], week: index + 1, valuesMaxWidth: c.maxWidth * 0.64),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
          label: Text('${index + 1}주차 체크하러 가기'),
        ),
      ],
    );
  }
}

/// 항목 한 줄. 칸이 여러 개면 '출석 ○', '후기 X'를 오른쪽 정렬 작은 줄로 쌓아요.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.week, required this.valuesMaxWidth});

  final ItemDef item;
  final int week;
  final double valuesMaxWidth;

  @override
  Widget build(BuildContext context) {
    final single = item.parts.length == 1;
    Widget value(PartDef part, String? subLabel) =>
        BigValue(part: part, week: week, itemId: item.id, subLabel: subLabel);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(item.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: valuesMaxWidth),
              child: single
                  ? value(item.parts.single, null)
                  // 여러 칸: 칸 이름 + 값 작은 줄을 오른쪽 정렬로 쌓아요
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var k = 0; k < item.parts.length; k++) ...[
                          if (k > 0) const SizedBox(height: 4),
                          value(item.parts[k], item.parts[k].label),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
