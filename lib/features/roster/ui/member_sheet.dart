import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../course/logic/course_providers.dart';
import '../../course/ui/course_picker_screen.dart' show groupCourses;
import '../data/roster_repository.dart';
import '../logic/roster_providers.dart';

/// 관리자 '사용자 관리'에서 사람을 누르면 올라오는 창: 반·마지막으로 올린 날,
/// '데이터 가져와 주기'(앱을 다시 깐 사람에게 예전 기록을 넣어 줘요), '반 옮기기', '출석부에서 지우기'(잘못 들어온 사람).
/// [courseMembers]는 그 반 출석부 전체예요(가져올 기록 후보). [movingTo]는 옮기는 중인 반 id.
Future<void> showMemberSheet(
  BuildContext context,
  Course course,
  Member m,
  List<Member> courseMembers, {
  String? movingTo,
}) => showAppSheet(
  context,
  scrollable: true,
  builder: (_) => _MemberSheet(course: course, member: m, courseMembers: courseMembers, movingTo: movingTo),
);

String _day(DateTime? d) => d == null ? '모름' : '${d.year}.${pad2(d.month)}.${pad2(d.day)}';

/// 문서 하나 설명: 마지막으로 올린 날 · 기록 있는 주 수 (사용자 목록·후보 목록이 같이 써요)
String memberDocLine(Member d) =>
    '마지막으로 올린 날 ${_day(d.updatedAt)} · ${d.record.isEmpty ? '기록 없음' : '${d.record.weekCount}주 기록'}';

class _MemberSheet extends ConsumerWidget {
  const _MemberSheet({required this.course, required this.member, required this.courseMembers, this.movingTo});

  final Course course;
  final Member member;
  final List<Member> courseMembers;
  final String? movingTo;

  /// 창을 닫고 서버 일을 한 뒤 알림. 끝나면 사용자 목록·출석부를 다시 읽어요.
  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() work, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    Navigator.of(context).pop();
    try {
      await work();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('하지 못했어요. 인터넷 연결을 확인해 주세요. ($e)')));
    }
    container.invalidate(adminUsersProvider);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final from = await showAppSheet<Member>(
      context,
      scrollable: true,
      builder: (_) => _ImportPicker(target: member, candidates: importCandidates(courseMembers, member)),
    );
    if (from == null || !context.mounted) return;
    final sameName = normalizeName(from.name) == normalizeName(member.name);
    final ok = await showConfirmDialog(
      context,
      title: '기록을 가져와 줄까요?',
      body:
          '${from.name} 님 기록(${memberDocLine(from)})을 ${member.name} 님 폰에 넣어 줘요.\n'
          '그 폰에서 앱을 다시 열면 비어 있는 칸만 채워져요.\n'
          '가져온 기록은 출석부에서 지워져요.'
          '${sameName ? '\n동명이인(다른 사람)이면 가져오지 마세요.' : '\n이름이 달라요. 같은 사람이 맞는지 꼭 확인해 주세요.\n${from.name} 님이 그 폰으로 앱을 계속 쓰고 있었다면, 다음에 앱을 열 때 반 고르기 화면이 떠요.'}',
      ok: '가져와 주기',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(adminRosterRepositoryProvider);
    await _run(context, ref, () => repo.giveBack(course.id, member, [from]), '${member.name} 님에게 기록을 가져와 줬어요.');
  }

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final to = await showAppSheet<Course>(
      context,
      scrollable: true,
      builder: (_) => _CoursePicker(name: member.name, exclude: course.id),
    );
    if (to == null || !context.mounted) return;
    final older = member.older.length;
    final ok = await showConfirmDialog(
      context,
      title: '${member.name} 님 반을 옮길까요?',
      body:
          '${course.fullTitle} → ${to.fullTitle}\n'
          '그 사람이 다음에 앱을 열면 새 반으로 바뀌어요.\n'
          '같은 체크 항목은 기록도 같이 옮겨지고(빈 칸만 채움), 예전 반 기록은 그 폰의 지난 출석부에 남아요.\n'
          '그때 지금 반 출석부에서 빠지고, 반장·총무 인정도 풀려요.'
          '${older == 0 ? '' : '\n같은 이름 예전 기록 $older개도 같이 옮겨요.'}',
      ok: '옮기기',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(adminRosterRepositoryProvider);
    await _run(
      context,
      ref,
      () => repo.moveMember(course.id, member, to.id),
      '${member.name} 님을 옮겨 두었어요. 앱을 열면 새 반으로 바뀌어요.',
    );
  }

  Future<void> _cancelMove(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(adminRosterRepositoryProvider);
    await _run(context, ref, () => repo.cancelMove(course.id, member), '${member.name} 님 반 옮기기를 취소했어요.');
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '${member.name} 님을 출석부에서 지울까요?',
      body:
          '${course.fullTitle} 출석부에서 빠지고, 반장·총무로 인정돼 있었다면 그것도 풀려요.\n'
          '같은 이름 예전 기록도 같이 지워져요.\n'
          '그 사람 폰에는 다음에 앱을 열 때 반 고르기 화면이 떠요.\n'
          '그 사람 폰의 체크 기록은 지워지지 않아요.',
      ok: '지우기',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(adminRosterRepositoryProvider);
    await _run(context, ref, () => repo.removeMembersNamed(course.id, member.name), '${member.name} 님을 출석부에서 지웠어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = importCandidates(courseMembers, member);
    final canImport = c.sameName.isNotEmpty || c.others.isNotEmpty;
    final moving = movingTo;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text(member.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        MutedText(course.fullTitle, style: const TextStyle(fontSize: 13)),
        MutedText(memberDocLine(member), style: const TextStyle(fontSize: 13)),
        if (c.sameName.isNotEmpty)
          MutedText('같은 이름 예전 기록 ${c.sameName.length}개 (앱을 다시 깔았거나 동명이인이면 생겨요)', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: canImport ? () => _import(context, ref) : null,
          icon: const Icon(Icons.restore_rounded),
          label: Text(canImport ? '데이터 가져와 주기' : '가져올 기록이 없어요'),
        ),
        const SizedBox(height: 4),
        const MutedText('앱을 다시 깔아 기록이 비었을 때, 같은 반의 예전 기록을 이 사람 폰에 넣어 줘요.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        if (moving == null)
          OutlinedButton.icon(
            onPressed: () => _move(context, ref),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('반 옮기기'),
          )
        else ...[
          MutedText(
            '${courseTitleOf(ref, moving)}(으)로 옮기는 중이에요. 그 사람이 앱을 열면 옮겨져요.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _cancelMove(context, ref),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('반 옮기기 취소'),
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

/// 가져올 기록 고르기: 같은 이름 기록을 먼저 보여 주고, 이름으로 찾아 고를 수도 있어요. 고른 문서를 돌려줘요.
class _ImportPicker extends StatefulWidget {
  const _ImportPicker({required this.target, required this.candidates});

  final Member target;
  final ({List<Member> sameName, List<Member> others}) candidates;

  @override
  State<_ImportPicker> createState() => _ImportPickerState();
}

class _ImportPickerState extends State<_ImportPicker> {
  String _query = '';

  Widget _tile(Member d) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(d.name),
    subtitle: Text(memberDocLine(d)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.of(context).pop(d),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 2),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final same = [
      for (final d in widget.candidates.sameName)
        if (nameMatches(d.name, _query)) d,
    ];
    final others = [
      for (final d in widget.candidates.others)
        if (nameMatches(d.name, _query)) d,
    ];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text('${widget.target.name} 님에게 가져올 기록', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const MutedText('같은 반 기록만 가져올 수 있어요.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '이름으로 찾기'),
          onChanged: (v) => setState(() => _query = v),
        ),
        if (same.isNotEmpty) ...[_header('같은 이름 기록'), for (final d in same) _tile(d)],
        if (others.isNotEmpty) ...[_header('다른 이름 기록'), for (final d in others) _tile(d)],
        if (same.isEmpty && others.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: MutedText('찾는 이름이 없어요.', textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

/// 반 id → 보이는 이름 (모르는 반이면 '다른 반')
String courseTitleOf(WidgetRef ref, String id) {
  for (final c in ref.watch(allCoursesProvider).valueOrNull ?? const <Course>[]) {
    if (c.id == id) return c.fullTitle;
  }
  return '다른 반';
}

/// 옮길 반 고르기: 사람들이 고를 수 있는 반(지금 학기·보이기 켠 반) 중 지금 반을 뺀 것. 고른 반을 돌려줘요.
class _CoursePicker extends ConsumerWidget {
  const _CoursePicker({required this.name, required this.exclude});

  final String name;
  final String exclude;

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: MutedText(text, textAlign: TextAlign.center),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(visibleCoursesProvider);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text('$name 님을 옮길 반', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const MutedText('지금 학기에 보이는 반만 고를 수 있어요.', style: TextStyle(fontSize: 13)),
        ...courses.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => [_note('반 목록을 못 불러왔어요. 인터넷 연결을 확인해 주세요.')],
          data: (list) {
            final groups = groupCourses([
              for (final c in list)
                if (c.id != exclude) c,
            ]);
            if (groups.isEmpty) return [_note('옮길 수 있는 다른 반이 없어요.')];
            return [
              for (final (title, group) in groups) ...[
                if (title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 2),
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                for (final c in group)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name.isEmpty ? '(이름 없는 반)' : c.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
            ];
          },
        ),
      ],
    );
  }
}
