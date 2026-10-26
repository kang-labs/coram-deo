import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../table/ui/record_grid.dart';
import '../../table/ui/table_image_export.dart';
import '../../week/logic/week_math.dart';
import '../../week/logic/week_providers.dart';
import '../../week/ui/week_range_text.dart';
import '../data/roster_repository.dart';
import '../logic/roster_providers.dart';

/// 넓은 화면(가로·폴드 펼침) 기준. 체크표와 같게.
const double _wideWidth = 600;

/// 반 출석부: 주차를 고르면 반 사람들(가나다순) × 항목 표. 보기만 해요.
/// 반장·총무 탭과 관리자 화면이 같이 써요. [canSave]면(관리자) 그 주 표를 그림으로 저장할 수 있고,
/// [canRemove]면(관리자) 이름을 눌러 잘못 들어온 사람을 출석부에서 지울 수 있어요.
class RosterView extends ConsumerStatefulWidget {
  const RosterView({
    super.key,
    required this.course,
    required this.members,
    this.canSave = false,
    this.canRemove = false,
  });

  final Course course;
  final AsyncValue<List<Member>> members;
  final bool canSave;
  final bool canRemove;

  @override
  ConsumerState<RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends ConsumerState<RosterView> {
  /// 고른 주차 순번(0부터). 처음엔 오늘 주.
  late int _week = (currentWeekIndex(widget.course.classDates, ref.read(todayProvider)) ?? 0).clamp(
    0,
    widget.course.weeks.isEmpty ? 0 : widget.course.weeks.length - 1,
  );

  Course get _c => widget.course;

  RecordGrid _grid(List<Member> unsorted, {required GridLayoutMode mode, GridDensity density = GridDensity.regular}) {
    final rows = rosterOrder(unsorted, _c);
    final members = [for (final r in rows) r.member];
    return RecordGrid(
      items: _c.items,
      headerLabel: '이름',
      firstColumnWidth: 84,
      mode: mode,
      density: density,
      rows: [
        for (final r in rows)
          RecordGridRow(
            title: r.member.name,
            subtitle: r.role,
            onTap: widget.canRemove && mode != GridLayoutMode.full ? () => _remove(r.member) : null,
          ),
      ],
      cellBuilder: (i, item, part, metrics) => RecordCellView.fromRecord(
        members[i].record,
        week: _week + 1,
        item: item,
        part: part,
        noteTitle: '${members[i].name} 사유',
        metrics: metrics,
      ),
    );
  }

  /// 관리자: 이 사람을 출석부에서 지워요. 그 사람 폰의 체크 기록은 그대로예요.
  Future<void> _remove(Member m) async {
    final ok = await showConfirmDialog(
      context,
      title: '${m.name} 님을 출석부에서 지울까요?',
      body:
          '이 반 출석부에서 빠지고, 반장·총무로 인정돼 있었다면 그것도 풀려요. 그 사람 폰의 체크 기록은 지워지지 않아요.\n'
          '그 사람이 이 반을 고른 채로 다시 체크하면 출석부에 다시 올라와요.',
      ok: '지우기',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRosterRepositoryProvider).removeMembersNamed(_c.id, m.name);
      messenger.showSnackBar(SnackBar(content: Text('${m.name} 님을 출석부에서 지웠어요.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('지우지 못했어요. 인터넷 연결을 확인해 주세요. ($e)')));
    }
  }

  Future<void> _save(List<Member> members) {
    final now = DateTime.now();
    final date = _c.weeks[_week].classDate;
    return exportGridImage(
      context,
      baseName: 'coram_deo_${_c.id}_${_week + 1}w_${now.year}${pad2(now.month)}${pad2(now.day)}',
      lines: [
        ExportLine(_c.fullTitle),
        ExportLine(
          '${_week + 1}주차${date == null ? '' : ' · ${md(weekRange(date).start)} ~ ${md(weekRange(date).end)}'}',
          ExportLineStyle.big,
        ),
        ExportLine('${members.length}명 · 저장일: ${now.year}.${pad2(now.month)}.${pad2(now.day)}', ExportLineStyle.small),
      ],
      grid: _grid(members, mode: GridLayoutMode.full),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_c.weeks.isEmpty) {
      return const EmptyState(icon: Icons.groups_rounded, title: '아직 일정표가 없어요', message: '일정이 생기면 주차별 출석부가 보여요.');
    }
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height || size.width >= _wideWidth;
    final last = _c.weeks.length - 1;
    final header = Row(
      children: [
        IconButton(
          tooltip: '지난 주',
          onPressed: _week > 0 ? () => setState(() => _week--) : null,
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
        ),
        Expanded(
          child: Column(
            children: [
              Text('${_week + 1}주차', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              WeekRangeText(
                classDate: _c.weeks[_week].classDate,
                style: TextStyle(fontSize: 13, color: p.inkSoft, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '다음 주',
          onPressed: _week < last ? () => setState(() => _week++) : null,
          icon: const Icon(Icons.chevron_right_rounded, size: 32),
        ),
      ],
    );
    return widget.members.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.cloud_off_rounded, title: '출석부를 못 불러왔어요', message: '인터넷 연결을 확인해 주세요.\n($e)'),
      data: (members) => ListView(
        padding: EdgeInsets.fromLTRB(wide ? 8 : AppLayout.sidePadding, 4, wide ? 8 : AppLayout.sidePadding, 24),
        children: [
          header,
          const SizedBox(height: 8),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: MutedText('아직 올라온 기록이 없어요. 반 사람들이 앱에서 이 반을 고르면 여기에 보여요.', textAlign: TextAlign.center),
            )
          else ...[
            _grid(
              members,
              mode: wide ? GridLayoutMode.fit : GridLayoutMode.scroll,
              density: wide ? GridDensity.compact : GridDensity.regular,
            ),
            const SizedBox(height: 12),
            MutedText(
              '${members.length}명 · 반장·총무 먼저, 나머지는 가나다순 · '
              '${widget.canRemove ? '이름을 누르면 출석부에서 지울 수 있어요.' : '보기만 할 수 있어요.'}'
              '${wide ? '' : ' 폰을 가로로 돌리면 표가 한눈에 보여요.'}',
              style: const TextStyle(fontSize: 13),
            ),
            if (widget.canSave) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _save(members),
                icon: const Icon(Icons.image_rounded),
                label: Text('${_week + 1}주차 출석부 이미지로 저장'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
