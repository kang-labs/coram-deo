import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../roster/data/roster_repository.dart';
import '../../roster/logic/roster_providers.dart';

/// 관리자: 반마다 출석부에 있는 사람 중에서 반장·총무·양육국 고르기
Future<void> showLeadersSheet(BuildContext context, Course course) => showAppSheet<void>(
  context,
  scrollable: true,
  builder: (sheet) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 16),
    children: [
      CardHeader(icon: Icons.badge_rounded, title: '${course.fullTitle} 반장·총무·양육국'),
      const SizedBox(height: 8),
      LeadersForm(course: course, onSaved: (_) => Navigator.pop(sheet)),
    ],
  ),
);

/// 반장·총무 칸 (고르기 목록 하나 = 역할 하나)
enum _Role {
  chief('반장'),
  treasurer('총무');

  const _Role(this.label);
  final String label;
}

/// 반장·총무(한 명씩)·양육국(여럿) 고르기와 저장 (반 메뉴 창, 반 편집 기본 정보 탭에서 같이 써요).
/// 셋 다 출석부를 보기만 해요. 저장은 바로 서버에 해요(반 편집의 '저장'과 따로).
/// [onSaved]는 저장한 사람들을 반 정보에 넣는 함수를 줘요.
class LeadersForm extends ConsumerStatefulWidget {
  const LeadersForm({super.key, required this.course, this.onSaved});

  final Course course;
  final void Function(Course Function(Course) apply)? onSaved;

  @override
  ConsumerState<LeadersForm> createState() => _LeadersFormState();
}

class _LeadersFormState extends ConsumerState<LeadersForm> {
  /// 고른 사람 uid (''이면 없음). 출석부를 받기 전에는 null(처음 값을 아직 안 정함).
  Map<_Role, String>? _picked;

  /// 고른 양육국 uid들 (출석부를 받기 전에는 null)
  Set<String>? _staff;
  bool _saving = false;

  /// 지금 정해진 사람의 uid. 예전(이름+코드) 반은 출석부에서 같은 이름인 사람으로 찾아요.
  String _currentUid(_Role r, List<Member> members) {
    final c = widget.course;
    final uid = r == _Role.chief ? c.chiefUid : c.treasurerUid;
    if (uid.isNotEmpty) return members.any((m) => m.uid == uid) ? uid : '';
    if (c.chiefUid.isNotEmpty || c.treasurerUid.isNotEmpty) return '';
    final name = normalizeName(r == _Role.chief ? c.chief : c.treasurer);
    if (name.isEmpty) return '';
    for (final m in members) {
      if (normalizeName(m.name) == name) return m.uid;
    }
    return '';
  }

  Future<void> _save(List<Member> members) async {
    final picked = _picked!;
    Member? pick(_Role r) {
      final uid = picked[r]!;
      if (uid.isEmpty) return null;
      for (final m in members) {
        if (m.uid == uid) return m;
      }
      return null;
    }

    final chief = pick(_Role.chief), treasurer = pick(_Role.treasurer);
    if (chief != null && chief.uid == treasurer?.uid) {
      await showInfoDialog(context, body: '반장과 총무는 다른 사람으로 골라 주세요.');
      return;
    }
    // 반장·총무로 고른 사람은 양육국에서 빼요(역할은 하나씩)
    final staff = [
      for (final m in members)
        if (_staff!.contains(m.uid) && m.uid != chief?.uid && m.uid != treasurer?.uid) m,
    ];
    setState(() => _saving = true);
    try {
      await ref
          .read(adminRosterRepositoryProvider)
          .saveLeaders(widget.course, chief: chief, treasurer: treasurer, staff: staff);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      widget.onSaved?.call(
        (c) => c.copyWith(
          chief: chief?.name ?? '',
          treasurer: treasurer?.name ?? '',
          chiefUid: chief?.uid ?? '',
          treasurerUid: treasurer?.uid ?? '',
          staff: [for (final m in staff) StaffRef(uid: m.uid, name: m.name)],
        ),
      );
      messenger.showSnackBar(const SnackBar(content: Text('저장했어요. 그 사람이 앱을 열면 출석부 탭이 생겨요.')));
    } on FirebaseException catch (e) {
      if (mounted) await showInfoDialog(context, title: '저장하지 못했어요', body: '권한이나 인터넷 연결을 확인해 주세요.\n(${e.code})');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminClassMembersProvider(widget.course.id));
    final members = async.valueOrNull;
    if (members == null) {
      return async.hasError
          ? const MutedText('출석부를 불러오지 못했어요. 인터넷 연결을 확인해 주세요.', style: TextStyle(fontSize: 13))
          : const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
    }
    // 처음 한 번만 지금 반장·총무로 채워요(뒤에 출석부가 바뀌어도 고르던 값은 그대로)
    final picked = _picked ??= {for (final r in _Role.values) r: _currentUid(r, members)};
    // 고른 사람이 그사이 출석부에서 빠졌으면 '없음'으로
    for (final r in _Role.values) {
      if (picked[r]!.isNotEmpty && !members.any((m) => m.uid == picked[r])) picked[r] = '';
    }
    final staff = _staff ??= {for (final s in widget.course.staff) s.uid};
    staff.retainWhere((uid) => members.any((m) => m.uid == uid));
    final c = widget.course;
    final missing = [
      for (final r in _Role.values)
        if ((r == _Role.chief ? c.chief : c.treasurer).isNotEmpty && _currentUid(r, members).isEmpty)
          '${r.label} ${r == _Role.chief ? c.chief : c.treasurer}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MutedText(
          members.isEmpty
              ? '아직 이 반 출석부에 올라온 사람이 없어요. 반 사람들이 앱에서 이 반을 고르면 여기에 나와요.'
              : '출석부에 있는 사람 중에서 골라 주세요. 고른 사람 폰에 출석부 탭이 생겨요(보기만 해요).\n'
                    '그 사람이 앱을 지우고 다시 깔았다면 출석부에 다시 올라온 이름으로 다시 골라 주세요.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          MutedText('${missing.join(', ')} 님은 출석부에 없어서 다시 골라야 해요.', style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
        for (final r in _Role.values) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // 출석부를 다시 받아도 고른 값이 맞게 보이게 고른 값으로 다시 만들어요
            key: ValueKey('${r.name}-${picked[r]}'),
            initialValue: picked[r],
            isExpanded: true,
            decoration: InputDecoration(labelText: r.label),
            items: [
              const DropdownMenuItem(value: '', child: Text('없음')),
              for (final m in members)
                DropdownMenuItem(
                  value: m.uid,
                  child: Text(m.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
            ],
            onChanged: _saving ? null : (v) => setState(() => picked[r] = v ?? ''),
          ),
        ],
        if (members.isNotEmpty) ...[
          const SizedBox(height: 16),
          const MutedText('양육국 (여러 명 고를 수 있어요)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in members)
                // 반장·총무로 고른 사람은 양육국으로 고를 수 없어요
                if (m.uid != picked[_Role.chief] && m.uid != picked[_Role.treasurer])
                  FilterChip(
                    label: Text(m.name),
                    selected: staff.contains(m.uid),
                    onSelected: _saving ? null : (on) => setState(() => on ? staff.add(m.uid) : staff.remove(m.uid)),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : () => _save(members), child: const Text('저장')),
      ],
    );
  }
}
