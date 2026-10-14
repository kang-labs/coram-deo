import 'package:coram_deo/app/theme.dart';
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/features/admin/ui/course_editor_screen.dart';
import 'package:coram_deo/features/course/data/course_repository.dart';
import 'package:coram_deo/features/course/logic/course_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_course.dart';

/// Firebase 없이 저장한 반만 모아 두는 가짜 저장소
class _FakeRepo implements CourseRepository {
  final saved = <Course>[];

  @override
  Future<void> save(Course course) async => saved.add(course);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<_FakeRepo> _open(
  WidgetTester tester,
  Course course, {
  bool isNew = false,
  double height = 5000,
  double width = 1080,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 2.7;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [courseRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.of(AppThemeId.blossom),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CourseEditorScreen(initial: course, isNew: isNew),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('새 반: 이름 없으면 안내, 이름 넣고 저장하면 닫힘', (tester) async {
    final repo = await _open(tester, fakeCourse().copyWith(name: ''), isNew: true);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('반 이름을 적어 주세요.'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '반 이름'), '  새 반  ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.name, '새 반');
    expect(find.byType(CourseEditorScreen), findsNothing);
  });

  testWidgets('고친 뒤 뒤로 가면 묻고, 나가기를 고르면 닫힘', (tester) async {
    await _open(tester, fakeCourse());
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    // 안 고쳤으면 바로 닫혀요
    nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(CourseEditorScreen), findsNothing);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '기수·학기'), '23기');
    await tester.pump(); // 다시 그려져야 PopScope가 '고침' 상태를 알아요
    nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseEditorScreen), findsNothing);
    expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
  });

  testWidgets('항목 추가: 새 id, 기존 id는 그대로', (tester) async {
    // 항목 15개가 한 화면에 다 들어오게 아주 길게
    final repo = await _open(tester, fakeCourse(), height: 30000);
    await tester.tap(find.text('체크 항목'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('항목 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '항목 이름').last, '전도');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final items = repo.saved.single.items;
    expect(items.length, 16);
    expect(items.take(15).map((e) => e.id), fakeCourse().items.map((e) => e.id));
    expect(items.last.id, startsWith('item_'));
    expect(items.last.label, '전도');
    // 칸 이름이 비면 항목 이름으로
    expect(items.last.parts.single, const PartDef(label: '전도', type: PartType.mark));
  });

  for (final dp in [360.0, 320.0]) {
    testWidgets('좁은 화면 ${dp.toInt()}dp: 편집 탭 넷 넘침 없음', (tester) async {
      await _open(tester, fakeCourse(), width: dp * 2.7, height: 800 * 2.7);
      for (final tab in ['기본 정보', '일정표', '체크 항목', '기록요령']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }
}
