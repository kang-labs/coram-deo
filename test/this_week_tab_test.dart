import 'package:coram_deo/app/app.dart';
import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/features/course/logic/course_providers.dart';
import 'package:coram_deo/features/home/logic/home_providers.dart';
import 'package:coram_deo/features/record/data/local_store.dart';
import 'package:coram_deo/features/week/logic/week_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_course.dart';

/// 오늘을 2026-10-14(수)로 고정 → 제자대학2학기 6주차(10/11~10/17)
class _FixedToday extends TodayController {
  @override
  DateTime build() => DateTime.utc(2026, 10, 14);
}

Future<(ProviderContainer, SharedPreferences)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(1080, 6000),
}) async {
  SharedPreferences.setMockInitialValues({LocalStore.courseIdKey: 'jedae2', LocalStore.nameKey: '홍길동'});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.7;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Firebase 없이: 반은 가짜 데이터로
      currentCourseProvider.overrideWith((ref) => Stream.value(fakeCourse())),
      todayProvider.overrideWith(_FixedToday.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CoramDeoApp()));
  await tester.pumpAndSettle();
  return (container, prefs);
}

void main() {
  testWidgets('이번 주: 6주차, 일정 카드, 항목 카드, 요일 체크·미래 날 막힘', (tester) async {
    final (_, prefs) = await _pumpApp(tester);

    expect(find.text('제자대학2학기'), findsOneWidget);
    expect(find.text('22기 2학기 · 홍길동'), findsOneWidget);
    expect(find.text('6주차'), findsOneWidget);
    expect(find.text('10/11(일) ~ 10/17(토)'), findsOneWidget);
    expect(find.text('세계비전의 기쁨 I'), findsOneWidget);
    expect(find.text('요 4:35\n행 2:47'), findsOneWidget);
    expect(find.text('출석/후기'), findsOneWidget);
    expect(find.text('금요기도회'), findsOneWidget);
    expect(find.text('0/7'), findsNWidgets(3)); // 성경·큐티·기도
    expect(find.text('0회 → −3'), findsOneWidget); // 새벽기도

    // 성경읽기(첫 요일 칸 묶음)에서 일요일 10/11 체크 → 1/7, 저장됨
    await tester.tap(find.bySemanticsLabel('10/11(일)').first);
    await tester.pump();
    expect(find.text('1/7'), findsOneWidget);
    expect(prefs.getString('rec.jedae2'), '{"6":{"bible":[1]}}');

    // 내일(10/15)은 아직 체크할 수 없어요
    await tester.tap(find.bySemanticsLabel('10/15(목)').first, warnIfMissed: false);
    await tester.pump();
    expect(find.text('1/7'), findsOneWidget);

    // 출석 ○ 고르고 다시 누르면 비움
    await tester.tap(find.text('○').first);
    await tester.pump();
    expect(prefs.getString('rec.jedae2'), '{"6":{"bible":[1],"attend":["o"]}}');
    await tester.tap(find.text('○').first);
    await tester.pump();
    expect(prefs.getString('rec.jedae2'), '{"6":{"bible":[1]}}');
  });

  testWidgets('주차 넘기기, 이번 주로 돌아오기, 체크표 줄 누르면 그 주로', (tester) async {
    final (container, _) = await _pumpApp(tester);

    await tester.tap(find.byTooltip('지난 주'));
    await tester.pumpAndSettle();
    expect(find.text('5주차'), findsOneWidget);
    await tester.tap(find.text('이번 주로'));
    await tester.pumpAndSettle();
    expect(find.text('6주차'), findsOneWidget);

    await tester.tap(find.text('체크표'));
    await tester.pumpAndSettle();
    expect(container.read(homeTabProvider), HomeTab.table);
    expect(find.text('휴강'), findsWidgets);
    await tester.tap(find.text('3주'));
    await tester.pumpAndSettle();
    expect(container.read(homeTabProvider), HomeTab.week);
    expect(find.text('3주차'), findsOneWidget);
  });

  // 좁은 화면(Flip 커버 361dp 정도, 아주 좁은 320dp)에서 네 탭 모두 넘침 없이 그려지는지
  for (final width in [361.0, 320.0]) {
    testWidgets('좁은 화면 ${width.toInt()}dp: 네 탭 넘침 없음', (tester) async {
      final (container, _) = await _pumpApp(tester, size: Size(width * 2.7, 700 * 2.7));
      for (final tab in HomeTab.values) {
        container.read(homeTabProvider.notifier).state = tab;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab');
      }
    });
  }
}
