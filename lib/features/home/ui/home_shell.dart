import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../course/logic/course_providers.dart';
import '../../course/ui/course_picker_screen.dart';
import '../../record/logic/record_providers.dart';
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
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(todayProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(homeTabProvider);
    final courseAsync = ref.watch(currentCourseProvider);
    final course = courseAsync.valueOrNull;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 64, title: _CourseTitle(course: course)),
      body: IndexedStack(
        index: tab.index,
        children: [
          for (final t in HomeTab.values)
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
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (i) => ref.read(homeTabProvider.notifier).state = HomeTab.values[i],
        destinations: [
          for (final t in HomeTab.values)
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
  const _CourseTitle({required this.course});

  final Course? course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(myNameProvider);
    final sub = [if (course?.term.isNotEmpty ?? false) course!.term, if (name.isNotEmpty) name].join(' · ');
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
