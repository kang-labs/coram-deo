import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/models/course.dart';
import '../../course/logic/course_providers.dart';
import '../../record/data/course_record.dart';
import '../../record/logic/record_providers.dart';
import '../../table/ui/check_table_tab.dart';
import '../../week/logic/week_math.dart';
import '../../week/logic/week_providers.dart';

/// 설정 > 지난 출석부: 전에 들은 반 목록 (보기만)
class PastBooksScreen extends ConsumerWidget {
  const PastBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(pastBooksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('지난 출석부')),
      body: books.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: '아직 지난 출석부가 없어요',
              message: '새 학기가 시작되거나 반을 바꾸면 전에 체크한 기록이 여기에 모여요.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 24),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = books[i].course;
                return SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => PastBookScreen(book: books[i]))),
                  child: Row(
                    children: [
                      const IconBubble(icon: Icons.menu_book_rounded, tone: Tone.accent, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.fullTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            MutedText(_periodLabel(c), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: context.palette.hint),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// 기간 글 (예: 2026.9.13 ~ 12.6 · 12주)
String _periodLabel(Course c) {
  final dates = c.classDates.nonNulls.toList();
  if (dates.isEmpty) return '${c.weeks.length}주';
  final first = dates.first, last = dates.last;
  final end = last.year == first.year ? md(last) : '${last.year}.${md(last)}';
  return '${first.year}.${md(first)} ~ $end · ${c.weeks.length}주';
}

/// 지난 출석부 한 권: 그때 체크표를 그대로 보여 줘요. 고칠 수는 없어요.
class PastBookScreen extends ConsumerWidget {
  const PastBookScreen({super.key, required this.book});

  final PastBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = book.course;
    final today = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(title: Text(c.fullTitle)),
      // 체크표 화면을 그대로 쓰되, 기록은 이 반 것으로, 고치기는 막고, 오늘 주 강조는 없앰
      body: ProviderScope(
        overrides: [
          courseRecordProvider.overrideWith(() => _FixedRecordController(book.record)),
          recordReadOnlyProvider.overrideWithValue(true),
          currentWeekIndexProvider.overrideWithValue(currentWeekIndex(c.classDates, today)),
          todayWeekIndexProvider.overrideWithValue(null),
        ],
        child: CheckTableTab(course: c),
      ),
    );
  }
}

/// 정해진 기록만 돌려주고 바꾸지 않는 기록
class _FixedRecordController extends CourseRecordController {
  _FixedRecordController(this._record);

  final CourseRecord _record;

  @override
  CourseRecord build() => _record;

  @override
  void setValue(int week, String itemId, String partId, Object? value, {String? note}) {}
}
