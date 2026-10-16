import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../install/ui/install_guide.dart';
import '../../record/logic/record_providers.dart';
import '../logic/course_providers.dart';

/// 처음 실행: 반 고르기 → 이번 주 화면
class CoursePickerScreen extends ConsumerWidget {
  const CoursePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const InstallBanner(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 40, AppLayout.sidePadding, 8),
                    sliver: SliverList.list(
                      children: [
                        Text('하나님앞에서', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const MutedText('내가 듣는 반을 골라 주세요. 체크 기록은 이 폰에만 저장돼요.'),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  CourseListSliver(onPicked: (c) => ref.read(selectedCourseIdProvider.notifier).select(c.id)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설정 > 반 바꾸기: 아래에서 올라오는 창으로 반 목록
Future<void> showCoursePickerSheet(BuildContext context, WidgetRef ref) {
  return showAppSheet(
    context,
    scrollable: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 8),
            sliver: SliverToBoxAdapter(child: MutedText('반을 바꿔도 기록은 반마다 따로 남아 있어요.')),
          ),
          CourseListSliver(
            onPicked: (c) {
              ref.read(selectedCourseIdProvider.notifier).select(c.id);
              Navigator.pop(sheet);
            },
          ),
        ],
      ),
    ),
  );
}

/// 고를 수 있는 반 목록 (보이기 켠 반만, 순서대로)
class CourseListSliver extends ConsumerWidget {
  const CourseListSliver({super.key, required this.onPicked});

  final ValueChanged<Course> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(visibleCoursesProvider);
    final selectedId = ref.watch(selectedCourseIdProvider);
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    return courses.when(
      loading: () => fill(const Center(child: CircularProgressIndicator())),
      error: (e, _) => fill(
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: '반 목록을 못 불러왔어요',
          message: '인터넷 연결을 확인하고 다시 열어 주세요.',
          action: OutlinedButton(onPressed: () => ref.invalidate(allCoursesProvider), child: const Text('다시 시도')),
        ),
      ),
      data: (list) => list.isEmpty
          ? fill(const EmptyState(icon: Icons.school_rounded, title: '아직 열린 반이 없어요', message: '관리자가 반을 등록하면 여기에 보여요.'))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 24),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final on = c.id == selectedId;
                  return SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    borderColor: on ? context.palette.primary : null,
                    onTap: () => onPicked(c),
                    child: Row(
                      children: [
                        IconBubble(icon: Icons.school_rounded, tone: on ? Tone.primary : Tone.accent, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              MutedText(
                                [if (c.term.isNotEmpty) c.term, '${c.scheduleLabel} 수업'].join(' · '),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (on) Icon(Icons.check_rounded, color: context.palette.primary),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
