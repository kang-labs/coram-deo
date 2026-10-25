import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../../core/models/course_defaults.dart';
import '../../course/data/course_repository.dart';
import '../../course/logic/course_providers.dart';
import '../logic/admin_providers.dart';
import 'course_editor_screen.dart';
import '../../roster/ui/roster_tab.dart';
import 'leaders_sheet.dart';

/// 관리자 모드: 구글 로그인(관리자 이메일만) → 반 목록
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 모드'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: '로그아웃',
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _addCourse(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('반 추가'),
            )
          : null,
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? const _SignInView()
          : !isAdmin
          ? EmptyState(
              icon: Icons.lock_rounded,
              title: '관리자 계정이 아니에요',
              message: '${user.email ?? '이 계정'}은 관리자로 등록되어 있지 않아요.',
              action: OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('다른 계정으로 로그인'),
              ),
            )
          : const _CourseAdminList(),
    );
  }

  Future<void> _addCourse(BuildContext context, WidgetRef ref) async {
    final list = ref.read(allCoursesProvider).valueOrNull ?? const <Course>[];
    // 지금 학기 반으로, 12주는 빈 날짜로 미리 만들어 둬요(1주 날짜를 넣으면 나머지가 7일씩 채워져요).
    final course = Course(
      id: ref.read(adminCourseRepositoryProvider).newId(),
      name: '',
      semester: ref.read(semesterProvider).valueOrNull ?? 0,
      order: _nextOrder(list),
      visible: false,
      weeks: List.filled(defaultWeekCount, const WeekInfo(date: '')),
      items: defaultItems,
      guide: defaultGuide,
    );
    await openCourseEditor(context, course, isNew: true);
  }
}

/// 서버 확인을 잠깐만 기다리고, 인터넷이 없으면 '나중에 올라가요' 안내 (화면이 멈추지 않게)
Future<void> _queued(BuildContext context, Future<void> write) async {
  final confirmed = await CourseRepository.confirmedWithin(write);
  if (!confirmed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인터넷이 연결되면 올라가요.')));
  }
}

int _nextOrder(List<Course> list) => list.fold(0, (m, c) => c.order > m ? c.order : m) + 1;

Future<void> openCourseEditor(BuildContext context, Course course, {bool isNew = false}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => CourseEditorScreen(initial: course, isNew: isNew),
  ),
);

class _SignInView extends ConsumerStatefulWidget {
  const _SignInView();

  @override
  ConsumerState<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<_SignInView> {
  final _pin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() signIn) async {
    setState(() => _busy = true);
    try {
      await signIn();
    } on FirebaseAuthException catch (e) {
      if (mounted) await showInfoDialog(context, title: '로그인하지 못했어요', body: _authMessage(e));
    } catch (e) {
      if (mounted) await showInfoDialog(context, title: '로그인하지 못했어요', body: '잠시 후 다시 시도해 주세요.\n($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
    'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' => '비밀번호가 맞지 않아요.',
    'too-many-requests' => '여러 번 틀려서 잠시 막혔어요. 조금 뒤에 다시 해 주세요.',
    'network-request-failed' => '인터넷 연결을 확인해 주세요.',
    'user-not-found' || 'operation-not-allowed' => '아직 관리자 비밀번호가 정해지지 않았어요.',
    _ => '잠시 후 다시 시도해 주세요. (${e.code})',
  };

  void _signInWithPin() {
    final pin = _pin.text.trim();
    if (pin.length != 6) {
      showInfoDialog(context, body: '숫자 6자리를 넣어 주세요.');
      return;
    }
    _run(() => ref.read(authRepositoryProvider).signInWithPin(pin));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 32, AppLayout.sidePadding, 24),
      children: [
        const Center(child: IconBubble(icon: Icons.admin_panel_settings_rounded, size: 64)),
        const SizedBox(height: 16),
        const Text(
          '관리자만 쓸 수 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const MutedText('관리자 비밀번호(숫자 6자리)를 넣어 주세요.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(hintText: '••••••', counterText: ''),
          onSubmitted: (_) => _signInWithPin(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _signInWithPin,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.login_rounded),
          label: const Text('로그인'),
        ),
        const SizedBox(height: 32),
        // 비밀번호를 잊었을 때만 쓰는 구글 로그인 (눈에 덜 띄게)
        TextButton(
          onPressed: _busy ? null : () => _run(() => ref.read(authRepositoryProvider).signInWithGoogle()),
          child: MutedText('비밀번호를 잊었어요 · 구글 계정으로 로그인', style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

/// 반 하나에 할 수 있는 일 (메뉴 순서대로)
enum _CourseAction { edit, roster, leaders, copy, toggleVisible, delete }

class _CourseAdminList extends ConsumerWidget {
  const _CourseAdminList();

  String _label(_CourseAction a, Course c) => switch (a) {
    _CourseAction.edit => '편집',
    _CourseAction.roster => '출석부 보기',
    _CourseAction.leaders => '반장·총무 정하기',
    _CourseAction.copy => '다음 기수로 복사',
    _CourseAction.toggleVisible => c.visible ? '숨기기' : '보이기',
    _CourseAction.delete => '삭제',
  };

  Future<void> _run(BuildContext context, WidgetRef ref, _CourseAction a, Course c, List<Course> all) async {
    final repo = ref.read(adminCourseRepositoryProvider);
    try {
      switch (a) {
        case _CourseAction.edit:
          await openCourseEditor(context, c);
        case _CourseAction.roster:
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminRosterScreen(course: c)));
        case _CourseAction.leaders:
          await showLeadersSheet(context, c);
        case _CourseAction.copy:
          // 항목·기록요령·일정 내용은 그대로, 기수 +1, 날짜만 비워서 다음 학기 반으로(숨김 상태).
          // 편집 > 일정표에서 1주 날짜를 넣으면 나머지 주가 7일씩 채워져요.
          // 다음 학기 = 지금 학기 + 1 (다음 학기 반을 또 복사해도 같은 학기로)
          final current = ref.read(semesterProvider).valueOrNull ?? c.semester;
          final copy = nextSemesterCopy(c, id: repo.newId(), semester: current + 1);
          await openCourseEditor(context, copy, isNew: true);
        case _CourseAction.toggleVisible:
          await _queued(context, repo.setVisible(c.id, !c.visible));
        case _CourseAction.delete:
          final ok = await showConfirmDialog(
            context,
            title: '${c.name}을(를) 삭제할까요?',
            body: '반이 목록에서 사라지고 되돌릴 수 없어요. 사람들 폰의 체크 기록은 남지만 이 반으로는 볼 수 없게 돼요.\n잠시 감추려면 숨기기를 쓰세요.',
            ok: '삭제',
          );
          if (ok && context.mounted) await _queued(context, repo.delete(c.id));
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        await showInfoDialog(context, title: '저장하지 못했어요', body: '권한이나 인터넷 연결을 확인해 주세요.\n(${e.code})');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(allCoursesProvider);
    // 학기 번호를 서버에서 확인하기 전에는 학기 넘기기를 막아요(모르는 값으로 넘기면 학기가 거꾸로 갈 수 있어요)
    final known = ref.watch(semesterProvider).valueOrNull;
    final semester = known ?? 0;
    return courses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: '반 목록을 못 불러왔어요', message: '$e'),
      data: (list) {
        final next = [
          for (final c in list)
            if (c.semester > semester) c,
        ];
        final now = [
          for (final c in list)
            if (c.semester == semester) c,
        ];
        final past = [
          for (final c in list)
            if (c.semester < semester) c,
        ];
        Widget card(Course c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AdminCourseCard(course: c, onAction: (a) => _run(context, ref, a, c, list), labelOf: _label),
        );
        Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 96),
          children: [
            if (known != null)
              _SemesterCard(semester: semester, current: now, next: next, all: list)
            else
              const MutedText('학기 정보를 확인하는 중이에요. 인터넷 연결을 확인해 주세요.'),
            if (next.isNotEmpty) ...[header('다음 학기 (준비 중, 사람들에게 아직 안 보여요)'), for (final c in next) card(c)],
            header('지금 학기'),
            if (now.isEmpty) const MutedText('지금 학기 반이 없어요. 아래 버튼으로 반을 추가해 주세요.') else for (final c in now) card(c),
            if (past.isNotEmpty) ...[header('지난 학기'), for (final c in past) card(c)],
          ],
        );
      },
    );
  }
}

/// 반 한 줄 (이름, 과정·기수, 요일, 주 수, 메뉴)
class _AdminCourseCard extends StatelessWidget {
  const _AdminCourseCard({required this.course, required this.onAction, required this.labelOf});

  final Course course;
  final ValueChanged<_CourseAction> onAction;
  final String Function(_CourseAction, Course) labelOf;

  @override
  Widget build(BuildContext context) {
    final c = course;
    return Opacity(
      opacity: c.visible ? 1 : 0.6,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        onTap: () => openCourseEditor(context, c),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.name.isEmpty ? '(이름 없음)' : c.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!c.visible) ...[const SizedBox(width: 6), const TinyBadge('숨김', tone: Tone.neutral)],
                    ],
                  ),
                  MutedText(
                    [
                      if (c.groupTitle.isNotEmpty) c.groupTitle,
                      c.scheduleLabel,
                      '${c.weeks.length}주',
                      '순서 ${c.order}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (c.chief.isNotEmpty || c.treasurer.isNotEmpty)
                    MutedText(
                      [
                        if (c.chief.isNotEmpty) '반장 ${c.chief}',
                        if (c.treasurer.isNotEmpty) '총무 ${c.treasurer}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            PopupMenuButton<_CourseAction>(
              tooltip: '더 보기',
              onSelected: onAction,
              itemBuilder: (_) => [
                for (final a in _CourseAction.values) PopupMenuItem(value: a, child: Text(labelOf(a, c))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 학기 넘기기: 다음 학기 반이 없으면 '다음 학기 준비하기', 있으면 '새 학기 시작하기'
class _SemesterCard extends ConsumerWidget {
  const _SemesterCard({required this.semester, required this.current, required this.next, required this.all});

  final int semester;
  final List<Course> current;
  final List<Course> next;
  final List<Course> all;

  Future<void> _prepare(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '다음 학기 반을 만들까요?',
      body:
          '지금 학기 반 ${current.length}개를 기수 +1로 복사해요. 일정 내용은 그대로 두고 날짜만 비워요.\n'
          '사람들에게는 새 학기를 시작할 때까지 안 보여요. 반마다 1주 날짜를 넣어 주세요.',
      ok: '만들기',
    );
    if (!ok || !context.mounted) return;
    await _guard(
      context,
      () => _queued(context, ref.read(adminCourseRepositoryProvider).prepareNextSemester(current, semester + 1)),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final undated = [
      for (final c in next)
        if (c.classDates.every((d) => d == null)) c.name,
    ];
    final ok = await showConfirmDialog(
      context,
      title: '새 학기를 시작할까요?',
      body:
          '다음 학기 반 ${next.length}개가 열리고 지금 반은 모두 숨겨져요.\n'
          '사람들은 앱을 열면 새 학기 반 고르기부터 하고, 하던 기록은 덜 끝났어도 설정 > 지난 출석부로 옮겨져요. 되돌릴 수 없어요.'
          '${undated.isEmpty ? '' : '\n\n아직 날짜가 없는 반: ${undated.join(', ')}'}',
      ok: '시작하기',
    );
    if (!ok || !context.mounted) return;
    await _guard(
      context,
      () => _queued(context, ref.read(adminCourseRepositoryProvider).startSemester(all, semester + 1)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardHeader(icon: Icons.event_repeat_rounded, title: '학기 넘기기', tone: Tone.warm),
          const SizedBox(height: 8),
          MutedText(
            next.isEmpty
                ? '${semester == 0 ? '아직 학기를 넘긴 적이 없어요' : '지금은 $semester번째 학기예요'}. 먼저 다음 학기 반을 만들고 날짜를 넣은 뒤 새 학기를 시작해요.'
                : "다음 학기 반 날짜를 다 넣었으면 새 학기를 시작해요. 빠진 반은 반 메뉴의 '다음 기수로 복사'로 더해요.",
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (next.isEmpty)
            OutlinedButton.icon(
              onPressed: current.isEmpty ? null : () => _prepare(context, ref),
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('다음 학기 준비하기'),
            )
          else
            FilledButton.icon(
              onPressed: () => _start(context, ref),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('새 학기 시작하기'),
            ),
        ],
      ),
    );
  }
}

/// 권한·인터넷 오류를 안내로 바꿔요
Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on FirebaseException catch (e) {
    if (context.mounted) {
      await showInfoDialog(context, title: '저장하지 못했어요', body: '권한이나 인터넷 연결을 확인해 주세요.\n(${e.code})');
    }
  }
}
