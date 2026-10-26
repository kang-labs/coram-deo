import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../data/roster_repository.dart';
import '../logic/roster_providers.dart';

/// 관리자: 출석부에서 이름을 누르면 올라오는 창. 번호·마지막으로 올린 날, 같은 이름 예전 기록,
/// '예전 기록 돌려주기'(앱을 다시 깐 사람)와 '출석부에서 지우기'(잘못 들어온 사람).
Future<void> showMemberSheet(BuildContext context, Course course, Member m) => showAppSheet(
  context,
  scrollable: true,
  builder: (_) => _MemberSheet(course: course, member: m),
);

String _day(DateTime? d) => d == null ? '모름' : '${d.year}.${pad2(d.month)}.${pad2(d.day)}';

class _MemberSheet extends ConsumerWidget {
  const _MemberSheet({required this.course, required this.member});

  final Course course;
  final Member member;

  /// 한 사람(문서) 줄: 번호 · 마지막으로 올린 날 · 기록 있는 주 수
  Widget _docLine(BuildContext context, Member d, {String? label}) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: MutedText(
      '${label == null ? '' : '$label · '}번호 ${shortUid(d.uid)} · 마지막으로 올린 날 ${_day(d.updatedAt)} · '
      '${d.record.isEmpty ? '기록 없음' : '${d.record.weekCount}주 기록'}',
      style: const TextStyle(fontSize: 13),
    ),
  );

  Future<void> _run(BuildContext context, Future<void> Function() work, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await work();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('하지 못했어요. 인터넷 연결을 확인해 주세요. ($e)')));
    }
  }

  Future<void> _giveBack(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '예전 기록을 돌려줄까요?',
      body:
          '같은 이름 예전 기록 ${member.older.length}개를 번호 ${shortUid(member.uid)} 폰에 돌려줘요.\n'
          '그 폰에서 앱을 다시 열면 비어 있는 칸만 채워져요.\n'
          '돌려준 뒤 예전 기록은 출석부에서 정리돼요.\n'
          '동명이인(다른 사람)이면 돌려주지 마세요.',
      ok: '돌려주기',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(adminRosterRepositoryProvider);
    await _run(context, () => repo.giveBackOlder(course.id, member), '${member.name} 님에게 예전 기록을 돌려줬어요.');
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '${member.name} 님을 출석부에서 지울까요?',
      body:
          '이 반 출석부에서 빠지고, 반장·총무로 인정돼 있었다면 그것도 풀려요.\n'
          '그 사람 폰에는 다음에 앱을 열 때 반 고르기 화면이 떠요.\n'
          '그 사람 폰의 체크 기록은 지워지지 않아요.',
      ok: '지우기',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(adminRosterRepositoryProvider);
    await _run(context, () => repo.removeMembersNamed(course.id, member.name), '${member.name} 님을 출석부에서 지웠어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGiveBack = member.older.any((o) => !o.record.isEmpty);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text(member.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        _docLine(context, member),
        if (member.older.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('같은 이름 예전 기록 ${member.older.length}개', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const MutedText('앱을 다시 깔았거나 동명이인이면 생겨요. 번호와 날짜로 구별해 주세요.', style: TextStyle(fontSize: 13)),
          for (final o in member.older) _docLine(context, o, label: '예전'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canGiveBack ? () => _giveBack(context, ref) : null,
            icon: const Icon(Icons.restore_rounded),
            label: Text(canGiveBack ? '예전 기록 돌려주기' : '돌려줄 예전 기록이 없어요'),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _remove(context, ref),
          icon: const Icon(Icons.person_remove_rounded),
          label: const Text('출석부에서 지우기'),
        ),
      ],
    );
  }
}
