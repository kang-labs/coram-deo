import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    final course = Course(
      id: ref.read(courseRepositoryProvider).newId(),
      name: '',
      order: _nextOrder(list),
      visible: false,
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
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        await showInfoDialog(context, title: '로그인하지 못했어요', body: '잠시 후 다시 시도해 주세요.\n($e)');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.admin_panel_settings_rounded,
      title: '관리자만 쓸 수 있어요',
      message: '반·일정표·체크 항목을 고치려면 관리자 구글 계정으로 로그인해 주세요.\n체크 기록은 로그인 없이 폰에만 저장돼요.',
      action: FilledButton.icon(
        onPressed: _busy ? null : _signIn,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.login_rounded),
        label: const Text('구글로 로그인'),
      ),
    );
  }
}

/// 반 하나에 할 수 있는 일 (메뉴 순서대로)
enum _CourseAction { edit, copy, toggleVisible, delete }

class _CourseAdminList extends ConsumerWidget {
  const _CourseAdminList();

  String _label(_CourseAction a, Course c) => switch (a) {
    _CourseAction.edit => '편집',
    _CourseAction.copy => '새 학기로 복사',
    _CourseAction.toggleVisible => c.visible ? '숨기기' : '보이기',
    _CourseAction.delete => '삭제',
  };

  Future<void> _run(BuildContext context, WidgetRef ref, _CourseAction a, Course c, List<Course> all) async {
    final repo = ref.read(courseRepositoryProvider);
    try {
      switch (a) {
        case _CourseAction.edit:
          await openCourseEditor(context, c);
        case _CourseAction.copy:
          // 항목·기록요령·일정 내용은 그대로, 날짜만 비워서 새 반으로(숨김 상태).
          // 편집 > 일정표에서 1주 날짜를 넣고 '7일씩 채우기'를 해야 저장할 수 있어요.
          final copy = c.copyWith(
            id: repo.newId(),
            term: c.term.isEmpty ? '새 학기' : '${c.term} (새 학기)',
            order: _nextOrder(all),
            visible: false,
            weeks: [for (final w in c.weeks) w.copyWith(date: '')],
            extras: [for (final e in c.extras) e.copyWith(date: '')],
          );
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
    return courses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: '반 목록을 못 불러왔어요', message: '$e'),
      data: (list) => list.isEmpty
          ? const EmptyState(icon: Icons.school_rounded, title: '아직 반이 없어요', message: '아래 버튼으로 반을 추가해 주세요.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = list[i];
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
                                  if (!c.visible) ...[
                                    const SizedBox(width: 6),
                                    const TinyBadge('숨김', tone: Tone.neutral),
                                  ],
                                ],
                              ),
                              MutedText(
                                [
                                  if (c.term.isNotEmpty) c.term,
                                  c.scheduleLabel,
                                  '${c.weeks.length}주',
                                  '순서 ${c.order}',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<_CourseAction>(
                          tooltip: '더 보기',
                          onSelected: (a) => _run(context, ref, a, c, list),
                          itemBuilder: (_) => [
                            for (final a in _CourseAction.values) PopupMenuItem(value: a, child: Text(_label(a, c))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
