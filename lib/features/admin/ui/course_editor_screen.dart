import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../../core/models/course_defaults.dart';
import '../../course/logic/course_providers.dart';

/// 반 편집: 기본 정보 / 일정표 / 체크 항목 / 기록요령. 저장을 눌러야 서버에 올라가요.
class CourseEditorScreen extends ConsumerStatefulWidget {
  const CourseEditorScreen({super.key, required this.initial, this.isNew = false});

  final Course initial;
  final bool isNew;

  @override
  ConsumerState<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

/// 편집 탭 (이름, 화면)
enum _Section {
  basic('기본 정보'),
  schedule('일정표'),
  items('체크 항목'),
  guide('기록요령');

  const _Section(this.label);

  final String label;
}

class _CourseEditorScreenState extends ConsumerState<CourseEditorScreen> {
  late Course _draft = widget.initial;
  bool _saving = false;

  /// 목록을 통째로 바꿀 때(자동 채우기 등) 올려서, 입력 칸이 새 값으로 다시 만들어지게 합니다.
  int _gen = 0;

  bool get _dirty => widget.isNew || _draft != widget.initial;

  void _update(Course next, {bool regenerate = false}) => setState(() {
    _draft = next;
    if (regenerate) _gen++;
  });

  String? _validate() {
    if (_draft.name.trim().isEmpty) return '반 이름을 적어 주세요.';
    for (var i = 0; i < _draft.weeks.length; i++) {
      if (_draft.weeks[i].classDate == null) return '${i + 1}주 날짜를 정해 주세요.';
    }
    if (_draft.items.isEmpty) return '체크 항목이 하나 이상 있어야 해요.';
    for (final item in _draft.items) {
      if (item.label.trim().isEmpty) return '이름 없는 체크 항목이 있어요.';
      if (item.parts.isEmpty) return '${item.label}에 칸이 하나 이상 있어야 해요.';
    }
    return null;
  }

  /// 저장 전 정리: 앞뒤 빈칸 지우고, 칸 이름이 비면 항목 이름으로
  Course _cleaned() => _draft.copyWith(
    name: _draft.name.trim(),
    term: _draft.term.trim(),
    time: _draft.time.trim(),
    items: [
      for (final item in _draft.items)
        item.copyWith(
          label: item.label.trim(),
          parts: [
            for (final p in item.parts) p.copyWith(label: p.label.trim().isEmpty ? item.label.trim() : p.label.trim()),
          ],
        ),
    ],
  );

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      await showInfoDialog(context, body: error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(courseRepositoryProvider).save(_cleaned());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요')));
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (mounted) {
        await showInfoDialog(context, title: '저장하지 못했어요', body: '권한이나 인터넷 연결을 확인해 주세요.\n(${e.code})');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showConfirmDialog(context, title: '저장하지 않고 나갈까요?', body: '고친 내용이 사라져요.', ok: '나가기');
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget section(_Section s) => switch (s) {
      _Section.basic => _BasicSection(draft: _draft, gen: _gen, onChanged: _update),
      _Section.schedule => _ScheduleSection(draft: _draft, gen: _gen, onChanged: _update),
      _Section.items => _ItemsSection(draft: _draft, gen: _gen, onChanged: _update),
      _Section.guide => _GuideSection(draft: _draft, gen: _gen, onChanged: _update),
    };
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: DefaultTabController(
        length: _Section.values.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.isNew ? '새 반' : '반 편집'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '저장 중' : '저장'),
                ),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tabs: [for (final s in _Section.values) Tab(text: s.label, height: 40)],
            ),
          ),
          body: TabBarView(children: [for (final s in _Section.values) section(s)]),
        ),
      ),
    );
  }
}

typedef _OnChanged = void Function(Course next, {bool regenerate});

/// 글자 입력 칸 하나. [fieldKey]가 같으면 다시 그려도 입력 중인 글자를 유지해요.
Widget _field(
  String fieldKey,
  String label,
  String initial,
  ValueChanged<String> onChanged, {
  int maxLines = 1,
  String? hint,
  TextInputType? keyboard,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(fieldKey),
      initialValue: initial,
      onChanged: onChanged,
      minLines: 1,
      maxLines: maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
    ),
  );
}

const _listPadding = EdgeInsets.fromLTRB(AppLayout.sidePadding, 16, AppLayout.sidePadding, 32);

class _BasicSection extends StatelessWidget {
  const _BasicSection({required this.draft, required this.gen, required this.onChanged});

  final Course draft;
  final int gen;
  final _OnChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    return ListView(
      padding: _listPadding,
      children: [
        _field('name$gen', '반 이름', d.name, (v) => onChanged(d.copyWith(name: v)), hint: '예: 제자대학2학기'),
        _field('term$gen', '기수·학기', d.term, (v) => onChanged(d.copyWith(term: v)), hint: '예: 22기 2학기'),
        const SheetLabel('수업 요일'),
        SelectPills<int>(
          options: SelectPills.simple({for (var w = 1; w <= 7; w++) w: weekdayLabel(w)}),
          selected: d.weekday,
          onSelected: (v) => onChanged(d.copyWith(weekday: v)),
        ),
        const SizedBox(height: 16),
        _field('time$gen', '수업 시간', d.time, (v) => onChanged(d.copyWith(time: v)), hint: '예: 18:00'),
        _field(
          'order$gen',
          '순서 (작을수록 위)',
          '${d.order}',
          (v) => onChanged(d.copyWith(order: int.tryParse(v.trim()) ?? d.order)),
          keyboard: TextInputType.number,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('반 목록에 보이기'),
          subtitle: const Text('끄면 사람들이 이 반을 고를 수 없어요'),
          value: d.visible,
          onChanged: (v) => onChanged(d.copyWith(visible: v)),
        ),
        const SizedBox(height: 8),
        MutedText('반 id: ${d.id}', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// 날짜 고르기 버튼 ('yyyy-MM-dd' 값)
class _DateButton extends StatelessWidget {
  const _DateButton({required this.value, required this.onPicked, this.empty = '날짜 고르기'});

  final String value;
  final ValueChanged<String> onPicked;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final d = tryParseYmd(value);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: d == null ? now : DateTime(d.year, d.month, d.day),
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onPicked(ymd(picked));
      },
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text(d == null ? empty : '${d.year}. ${mdw(d)}'),
    );
  }
}

class _ScheduleSection extends StatefulWidget {
  const _ScheduleSection({required this.draft, required this.gen, required this.onChanged});

  final Course draft;
  final int gen;
  final _OnChanged onChanged;

  @override
  State<_ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<_ScheduleSection> {
  late String _first = widget.draft.weeks.isEmpty ? '' : widget.draft.weeks.first.date;
  late int _count = widget.draft.weeks.isEmpty ? defaultWeekCount : widget.draft.weeks.length;

  Course get d => widget.draft;

  void _setWeek(int i, WeekInfo w) => widget.onChanged(d.copyWith(weeks: [...d.weeks]..[i] = w));

  void _setExtra(int i, ExtraRow e) => widget.onChanged(d.copyWith(extras: [...d.extras]..[i] = e));

  Future<void> _autoFill() async {
    final first = tryParseYmd(_first);
    if (first == null) return;
    if (d.weeks.isNotEmpty) {
      final ok = await showConfirmDialog(
        context,
        title: '날짜를 다시 채울까요?',
        body:
            '1주부터 7일씩 $_count주 날짜를 새로 넣어요. 주마다 적은 내용은 순서대로 그대로 남아요.'
            '${_count < d.weeks.length ? '\n${_count + 1}주부터는 지워져요.' : ''}',
        ok: '채우기',
      );
      if (!ok) return;
    }
    widget.onChanged(d.copyWith(weeks: fillWeeks(first, _count, d.weeks)), regenerate: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final g = widget.gen;
    final first = tryParseYmd(_first);
    return ListView(
      padding: _listPadding,
      children: [
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardHeader(icon: Icons.date_range_rounded, title: '날짜 자동 채우기'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _DateButton(value: _first, empty: '1주 날짜', onPicked: (v) => setState(() => _first = v)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '한 주 빼기',
                        onPressed: _count > 1 ? () => setState(() => _count--) : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text('$_count주', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: '한 주 더하기',
                        onPressed: _count < 52 ? () => setState(() => _count++) : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
              if (first != null && first.weekday != d.weekday)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '1주 날짜가 ${weekdayLabel(first.weekday)}요일이에요. 수업 요일(${weekdayLabel(d.weekday)})과 달라요.',
                    style: TextStyle(color: p.danger, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(onPressed: first == null ? null : _autoFill, child: const Text('7일씩 채우기')),
            ],
          ),
        ),
        for (var i = 0; i < d.weeks.length; i++) ...[
          const SizedBox(height: 12),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            color: d.weeks[i].off ? p.surfaceMuted : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('${i + 1}주', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: _DateButton(
                        value: d.weeks[i].date,
                        onPicked: (v) => _setWeek(i, d.weeks[i].copyWith(date: v)),
                      ),
                    ),
                    const Spacer(),
                    const Text('휴강'),
                    Switch(
                      value: d.weeks[i].off,
                      onChanged: (v) => _setWeek(i, d.weeks[i].copyWith(off: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final f in _weekFields)
                  _field(
                    'w$i/${f.key}/$g',
                    f.label,
                    f.get(d.weeks[i]),
                    (v) => _setWeek(i, f.set(d.weeks[i], v)),
                    maxLines: f.multiline ? 4 : 1,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const CardHeader(icon: Icons.event_rounded, title: '추가 줄 (개강·졸업예배 등)', tone: Tone.accent),
        for (var i = 0; i < d.extras.length; i++) ...[
          const SizedBox(height: 12),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _DateButton(
                        value: d.extras[i].date,
                        onPicked: (v) => _setExtra(i, d.extras[i].copyWith(date: v)),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '이 줄 지우기',
                      onPressed: () =>
                          widget.onChanged(d.copyWith(extras: [...d.extras]..removeAt(i)), regenerate: true),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _field(
                  'e$i/label/$g',
                  '이름',
                  d.extras[i].label,
                  (v) => _setExtra(i, d.extras[i].copyWith(label: v)),
                  hint: '예: 개강',
                ),
                _field(
                  'e$i/title/$g',
                  '내용',
                  d.extras[i].title,
                  (v) => _setExtra(i, d.extras[i].copyWith(title: v)),
                  hint: '예: OT',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => widget.onChanged(
            d.copyWith(
              extras: [
                ...d.extras,
                const ExtraRow(label: '', date: ''),
              ],
            ),
            regenerate: true,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('줄 추가'),
        ),
      ],
    );
  }
}

/// 주마다 고치는 글 칸 (데이터로 정의해서 칸마다 코드를 복사하지 않아요)
typedef _WeekField = ({
  String key,
  String label,
  bool multiline,
  String Function(WeekInfo) get,
  WeekInfo Function(WeekInfo, String) set,
});

final List<_WeekField> _weekFields = [
  (key: 'book', label: '교재', multiline: false, get: (w) => w.book, set: (w, v) => w.copyWith(book: v)),
  (key: 'title', label: '훈련 내용', multiline: true, get: (w) => w.title, set: (w, v) => w.copyWith(title: v)),
  (key: 'verses', label: '암송구절 (한 줄에 하나)', multiline: true, get: (w) => w.verses, set: (w, v) => w.copyWith(verses: v)),
  (key: 'sharing', label: '나눔', multiline: true, get: (w) => w.sharing, set: (w, v) => w.copyWith(sharing: v)),
];

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.draft, required this.gen, required this.onChanged});

  final Course draft;
  final int gen;
  final _OnChanged onChanged;

  List<ItemDef> get items => draft.items;

  void _setItem(int i, ItemDef item, {bool regenerate = false}) =>
      onChanged(draft.copyWith(items: [...items]..[i] = item), regenerate: regenerate);

  void _setPart(int i, int k, PartDef part, {bool regenerate = false}) =>
      _setItem(i, items[i].copyWith(parts: [...items[i].parts]..[k] = part), regenerate: regenerate);

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: _listPadding,
      buildDefaultDragHandles: false,
      header: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: MutedText('왼쪽 손잡이를 끌어 순서를 바꿔요. 항목을 지우면 그 항목의 체크 기록이 화면에서 안 보이게 돼요.', style: TextStyle(fontSize: 13)),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: OutlinedButton.icon(
          onPressed: () => onChanged(
            draft.copyWith(
              items: [
                ...items,
                ItemDef(
                  id: newItemId(items.map((e) => e.id)),
                  label: '',
                  parts: const [PartDef(label: '', type: PartType.mark)],
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('항목 추가'),
        ),
      ),
      itemCount: items.length,
      onReorderItem: (from, to) {
        final list = [...items];
        list.insert(to, list.removeAt(from));
        onChanged(draft.copyWith(items: list));
      },
      itemBuilder: (context, i) {
        final item = items[i];
        final typeOptions = {for (final t in PartType.values) t: t.label};
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.drag_indicator_rounded)),
                    ),
                    Expanded(
                      child: _field(
                        '${item.id}/label/$gen',
                        '항목 이름',
                        item.label,
                        (v) => _setItem(i, item.copyWith(label: v)),
                      ),
                    ),
                    IconButton(
                      tooltip: '항목 지우기',
                      onPressed: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: '${item.label.isEmpty ? '이 항목' : item.label}을(를) 지울까요?',
                          body: '저장하면 사람들 화면에서 이 항목이 사라져요.',
                          ok: '지우기',
                        );
                        if (ok) onChanged(draft.copyWith(items: [...items]..removeAt(i)), regenerate: true);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                for (var k = 0; k < item.parts.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(
                            '${item.id}/p$k/$gen',
                            '칸 ${k + 1} 이름',
                            item.parts[k].label,
                            (v) => _setPart(i, k, item.parts[k].copyWith(label: v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: AppDropdown<PartType>(
                            options: typeOptions,
                            value: item.parts[k].type,
                            onChanged: (t) => _setPart(i, k, item.parts[k].copyWith(type: t)),
                          ),
                        ),
                        IconButton(
                          tooltip: '칸 지우기',
                          onPressed: item.parts.length > 1
                              ? () => _setItem(i, item.copyWith(parts: [...item.parts]..removeAt(k)), regenerate: true)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _setItem(
                          i,
                          item.copyWith(
                            parts: [
                              ...item.parts,
                              const PartDef(label: '', type: PartType.mark),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('칸 추가'),
                      ),
                      const Spacer(),
                      MutedText('id: ${item.id}', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.draft, required this.gen, required this.onChanged});

  final Course draft;
  final int gen;
  final _OnChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _listPadding,
      children: [
        _field('guide$gen', '기록요령', draft.guide, (v) => onChanged(draft.copyWith(guide: v)), maxLines: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await showConfirmDialog(context, title: '기본 글로 되돌릴까요?', body: '지금 적은 글은 사라져요.', ok: '되돌리기');
              if (ok) onChanged(draft.copyWith(guide: defaultGuide), regenerate: true);
            },
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('기본 글로 되돌리기'),
          ),
        ),
      ],
    );
  }
}
