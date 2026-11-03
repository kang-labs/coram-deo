import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../course/logic/course_providers.dart';
import '../../course/ui/course_picker_screen.dart';
import '../../install/ui/install_guide.dart';
import '../../record/logic/record_providers.dart';
import '../../roster/logic/roster_providers.dart';
import '../../roster/ui/roster_tab.dart';
import '../../schedule/ui/schedule_tab.dart';
import '../../settings/ui/settings_tab.dart';
import '../../table/ui/check_table_tab.dart';
import '../../week/logic/week_providers.dart';
import '../../week/ui/this_week_tab.dart';
import '../logic/home_providers.dart';

/// 하단 탭 하나 (이름, 아이콘, 화면). 반이 없으면 [needsCourse] 탭은 안내를 보여요.
typedef _TabSpec = ({
  String label,
  IconData icon,
  IconData selectedIcon,
  bool needsCourse,
  Widget Function(Course?) build,
});

final _tabs = <HomeTab, _TabSpec>{
  HomeTab.week: (
    label: '이번 주',
    icon: Icons.check_box_outlined,
    selectedIcon: Icons.check_box_rounded,
    needsCourse: true,
    build: (c) => ThisWeekTab(course: c!),
  ),
  HomeTab.table: (
    label: '체크표',
    icon: Icons.grid_on_outlined,
    selectedIcon: Icons.grid_on_rounded,
    needsCourse: true,
    build: (c) => CheckTableTab(course: c!),
  ),
  HomeTab.roster: (
    label: '출석부',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    needsCourse: true,
    build: (c) => RosterTab(course: c!),
  ),
  HomeTab.schedule: (
    label: '일정표',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note_rounded,
    needsCourse: true,
    build: (c) => ScheduleTab(course: c!),
  ),
  HomeTab.settings: (
    label: '설정',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    needsCourse: false,
    build: (c) => SettingsTab(course: c),
  ),
};

/// 하단 탭 4개 (이번 주 / 체크표 / 일정표 / 설정)
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // 자정을 넘겨 앱을 다시 열면 오늘·이번 주를 새로 계산해요.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(todayProvider.notifier).refresh();
        _checkServer();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkServer());
  }

  /// 마지막으로 서버에 관리자 조치(반 옮기기·지우기·예전 기록 돌려주기)를 물어본 때.
  /// 앱을 자주 오가도 15분에 한 번만 물어요(문서 몇 개 읽기라 사용량·배터리 부담이 작아요).
  DateTime? _serverCheckedAt;

  /// 앱을 열거나 돌아올 때: 관리자가 출석부에서 지웠으면 알리고 반 고르기부터,
  /// 예전 기록을 돌려줬으면 빈 칸에 채우고 알려요.
  Future<void> _checkServer() async {
    final now = DateTime.now();
    if (_serverCheckedAt != null && now.difference(_serverCheckedAt!) < const Duration(minutes: 15)) return;
    _serverCheckedAt = now;
    // 옮기기를 먼저 봐요: 옮긴 뒤에는 옛 반 문서가 없어져 '지워졌다'로 잘못 알 수 있어서예요
    final (:moved, :pending) = await takeMove(ref);
    if (pending) return;
    if (moved != null && mounted) {
      await showInfoDialog(
        context,
        title: '반이 바뀌었어요',
        body:
            '관리자가 반을 옮겼어요.\n새 반: ${moved.fullTitle}\n'
            '같은 체크 항목은 기록도 같이 옮겼어요. 예전 반 기록은 설정 > 지난 출석부에 남아 있어요.',
      );
    }
    if (await checkRemovedByAdmin(ref)) {
      if (mounted) await _onRemoved();
      return;
    }
    if (await takeRestoredRecord(ref) && mounted) {
      await showInfoDialog(
        context,
        title: '예전 기록을 돌려받았어요',
        body: '관리자가 돌려준 예전 체크 기록으로 비어 있던 칸을 채웠어요.\n이미 체크한 칸은 그대로예요.',
      );
    }
  }

  /// 관리자가 출석부에서 지웠을 때: 알려 주고 반 고르기부터 다시 해요. 체크 기록은 폰에 그대로 남아요.
  Future<void> _onRemoved() async {
    final title = ref.read(currentCourseProvider).valueOrNull?.fullTitle;
    await showInfoDialog(
      context,
      title: '반을 다시 골라 주세요',
      body:
          '관리자가 ${title == null ? '이 반' : "'$title'"} 출석부에서 이름을 뺐어요.\n'
          '체크 기록은 이 폰에 그대로 있어요.',
    );
    if (mounted) await ref.read(selectedCourseIdProvider.notifier).clear();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Widget _tabStack(List<HomeTab> shown, HomeTab tab, Course? course, AsyncValue<Course?> courseAsync) {
    return IndexedStack(
      index: shown.indexOf(tab),
      children: [
        for (final t in shown)
          KeyedSubtree(
            key: ValueKey(t),
            child: !_tabs[t]!.needsCourse || course != null
                ? _tabs[t]!.build(course)
                : courseAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.school_rounded,
                    title: courseAsync.hasError ? '반 정보를 못 불러왔어요' : '반을 찾을 수 없어요',
                    message: courseAsync.hasError ? '인터넷 연결을 확인해 주세요.' : '반이 없어졌거나 바뀌었어요. 반을 다시 골라 주세요.',
                    action: FilledButton(
                      onPressed: () => showCoursePickerSheet(context, ref),
                      child: const Text('반 고르기'),
                    ),
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 내 기록을 서버에 올려요(체크가 바뀌면 3초 뒤 한 번). 반장·총무·관리자가 봐요.
    ref.watch(memberSyncProvider);
    // 반을 바꾸는 중에는 이전 반 값이 남아 있으니 확인이 끝난 뒤에만 출석부 탭을 보여요
    final leaderState = ref.watch(isLeaderProvider);
    final leader = !leaderState.isLoading && (leaderState.valueOrNull ?? false);
    final shown = [
      for (final t in HomeTab.values)
        if (t != HomeTab.roster || leader) t,
    ];
    final picked = ref.watch(homeTabProvider);
    final tab = shown.contains(picked) ? picked : HomeTab.week;
    final courseAsync = ref.watch(currentCourseProvider);
    final course = courseAsync.valueOrNull;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;
    return Scaffold(
      // 가로 화면은 제목줄을 낮춰 표가 더 많이 보이게 (이름 줄은 빼요)
      appBar: AppBar(
        toolbarHeight: wide ? 44 : 64,
        title: _CourseTitle(course: course, compact: wide),
      ),
      body: Column(
        children: [
          const InstallBanner(),
          Expanded(child: _tabStack(shown, tab, course, courseAsync)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shown.indexOf(tab),
        onDestinationSelected: (i) => ref.read(homeTabProvider.notifier).state = shown[i],
        destinations: [
          for (final t in shown)
            NavigationDestination(
              icon: Icon(_tabs[t]!.icon),
              selectedIcon: Icon(_tabs[t]!.selectedIcon),
              label: _tabs[t]!.label,
            ),
        ],
      ),
    );
  }
}

/// 앱바 제목: 반 이름 + 기수·학기 · 내 이름
class _CourseTitle extends ConsumerWidget {
  const _CourseTitle({required this.course, this.compact = false});

  final Course? course;

  /// 가로 화면: 한 줄만 (반 이름)
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(myNameProvider);
    final group = course?.groupTitle ?? '';
    final sub = compact ? '' : [if (group.isNotEmpty) group, if (name.isNotEmpty) name].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(course?.name ?? '하나님앞에서', maxLines: 1, overflow: TextOverflow.ellipsis),
        if (sub.isNotEmpty)
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.inkSoft),
          ),
      ],
    );
  }
}
