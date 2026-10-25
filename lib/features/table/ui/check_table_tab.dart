import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../home/logic/home_providers.dart';
import '../../record/logic/record_providers.dart';
import '../../week/logic/week_providers.dart';
import '../logic/table_view_provider.dart';
import 'record_grid.dart';
import 'table_image_export.dart';
import 'week_pages_view.dart';

/// 가로 폭이 이만큼 넘는 화면(가로로 눕힌 폰, 펼친 폴드)은 표를 한눈에 보게 줄여요
const double _wideWidth = 600;

/// 체크표 탭: 위에 '주별 | 표' 고르기(기기에 기억), 아래에 고른 보기.
class CheckTableTab extends ConsumerWidget {
  const CheckTableTab({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (course.weeks.isEmpty) {
      return const EmptyState(icon: Icons.grid_on_rounded, title: '아직 일정표가 없어요', message: '일정이 생기면 주차별 체크표가 보여요.');
    }
    final view = ref.watch(tableViewProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 4),
          child: Row(
            children: [
              SelectPills<TableView>(
                options: SelectPills.simple({for (final v in TableView.values) v: v.label}),
                selected: view,
                onSelected: (v) {
                  if (v != null) ref.read(tableViewProvider.notifier).select(v);
                },
              ),
              const Spacer(),
              if (view == TableView.grid) _SaveImageButton(course: course),
            ],
          ),
        ),
        Expanded(
          child: switch (view) {
            TableView.week => WeekPagesView(key: ValueKey(course.id), course: course),
            TableView.grid => _GridView(course: course),
          },
        ),
      ],
    );
  }
}

/// 표 보기: 종이와 같은 표(주차 × 항목). 주차 줄을 누르면 그 주 '이번 주' 화면으로 갑니다.
/// 세로 화면은 첫 열(주차)을 고정하고 가로로 밀어 보고, 가로로 넓은 화면은 한눈에 보이게 줄여요.
class _GridView extends StatelessWidget {
  const _GridView({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height || size.width >= _wideWidth;
    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 8 : AppLayout.sidePadding, 8, wide ? 8 : AppLayout.sidePadding, 24),
      children: [
        WeekRecordGrid(
          course: course,
          mode: wide ? GridLayoutMode.fit : GridLayoutMode.scroll,
          density: wide ? GridDensity.compact : GridDensity.regular,
        ),
        const SizedBox(height: 12),
        MutedText(
          wide ? '주차 줄을 누르면 그 주 체크 화면으로 가요.' : '표를 옆으로 밀어 모든 항목을 볼 수 있어요. 주차 줄을 누르면 그 주 체크 화면으로 가요.',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

/// 내 체크표 표: 줄 = 주차, 칸 값은 내 기록([courseRecordProvider])에서 칸마다 읽어요.
class WeekRecordGrid extends ConsumerWidget {
  const WeekRecordGrid({
    super.key,
    required this.course,
    this.mode = GridLayoutMode.scroll,
    this.density = GridDensity.regular,
  });

  final Course course;
  final GridLayoutMode mode;
  final GridDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayIndex = ref.watch(todayWeekIndexProvider);
    final readOnly = ref.watch(recordReadOnlyProvider);
    return RecordGrid(
      items: course.items,
      headerLabel: '주차',
      mode: mode,
      density: density,
      rows: [
        for (var i = 0; i < course.weeks.length; i++)
          RecordGridRow(
            title: '${i + 1}주',
            subtitle: course.weeks[i].off ? '휴강' : _md(course.weeks[i]),
            dim: course.weeks[i].off,
            highlight: i == todayIndex,
            onTap: readOnly
                ? null
                : () {
                    ref.read(pickedWeekProvider.notifier).state = i;
                    ref.read(homeTabProvider.notifier).state = HomeTab.week;
                  },
          ),
      ],
      cellBuilder: (row, item, part, m) => ProviderRecordCell(week: row + 1, item: item, part: part, metrics: m),
    );
  }

  static String _md(WeekInfo w) {
    final d = w.classDate;
    return d == null ? '' : md(d);
  }
}

/// '이미지로 저장': 모든 주차 × 모든 항목을 제목·이름과 함께 그림으로 저장해요.
class _SaveImageButton extends ConsumerStatefulWidget {
  const _SaveImageButton({required this.course});

  final Course course;

  @override
  ConsumerState<_SaveImageButton> createState() => _SaveImageButtonState();
}

class _SaveImageButtonState extends ConsumerState<_SaveImageButton> {
  bool _saving = false; // 저장하는 동안 또 눌리지 않게

  Future<void> _save() async {
    final name = ref.read(myNameProvider).trim();
    if (name.isEmpty) {
      await showInfoDialog(context, title: '이름을 먼저 적어 주세요', body: '저장하는 그림에 이름이 들어가요.\n설정 > 내 이름에 이름을 적고 다시 눌러 주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await exportGridImage(
        context,
        baseName: 'coram_deo_${ymd(now).replaceAll('-', '')}_${pad2(now.hour)}${pad2(now.minute)}${pad2(now.second)}',
        lines: [
          ExportLine(widget.course.fullTitle),
          ExportLine('이름: $name', ExportLineStyle.big),
          ExportLine('저장일: ${now.year}.${pad2(now.month)}.${pad2(now.day)}', ExportLineStyle.small),
        ],
        // 줄이거나 밀지 않은 원래 크기 표 (화면에 보이는 부분이 아니라 전체)
        grid: WeekRecordGrid(course: widget.course, mode: GridLayoutMode.full),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _saving ? null : _save,
    icon: const Icon(Icons.image_outlined, size: 20),
    label: const Text('이미지로 저장'),
  );
}
