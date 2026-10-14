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
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues({LocalStore.courseIdKey: 'jedae2', LocalStore.nameKey: '홍길동', ...saved});
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
    // 400dp 폭에서는 요일까지 넣으면 한 줄에 안 들어가서 짧게 (두 줄로 꺾이지 않게)
    expect(find.text('10/11~10/17'), findsOneWidget);
    expect(find.text('세계비전의 기쁨 I'), findsOneWidget);
    // 본문이 있으면 본문 뒤에 (장절)을 붙인 한 문단, 없으면 장절만
    expect(find.text('눈을 들어 밭을 보라 (요 4:35)', findRichText: true), findsOneWidget);
    expect(find.text('행 2:47'), findsOneWidget);
    expect(find.text('훈련'), findsOneWidget);
    expect(find.text('금요기도회'), findsOneWidget);
    expect(find.text('0/7'), findsNWidgets(4)); // 성경·큐티·기도·새벽기도

    // 성경읽기(첫 요일 칸 묶음)에서 일요일 10/11 체크 → 1/7, 저장됨
    await tester.tap(find.bySemanticsLabel('10/11(일)').first);
    await tester.pump();
    expect(find.text('1/7'), findsOneWidget);
    expect(prefs.getString('rec.jedae2'), '{"6":{"bible":{"main":1}}}');

    // 내일(10/15)은 아직 체크할 수 없어요
    await tester.tap(find.bySemanticsLabel('10/15(목)').first, warnIfMissed: false);
    await tester.pump();
    expect(find.text('1/7'), findsOneWidget);

    // 출석 ○ 고르고 다시 누르면 비움
    await tester.tap(find.bySemanticsLabel('○').first);
    await tester.pump();
    expect(prefs.getString('rec.jedae2'), '{"6":{"bible":{"main":1},"attend":{"att":"o"}}}');
    await tester.tap(find.bySemanticsLabel('○').first);
    await tester.pump();
    expect(prefs.getString('rec.jedae2'), '{"6":{"bible":{"main":1}}}');

    // 출석 버튼 순서 ○ / X / 지각, 교재예습은 ○ / X / ·, 구절암송은 ○ / X
    expect(find.bySemanticsLabel('지각'), findsOneWidget);
    expect(find.bySemanticsLabel('·'), findsNWidgets(14)); // mark 칸 14개 (후기·금요기도회 등)
  });

  testWidgets('· 고르면 사유를 꼭 적고(취소하면 그대로), 줄 아래 보이며, 다른 값으로 바꾸면 지워짐', (tester) async {
    final (_, prefs) = await _pumpApp(tester);
    // 교재예습(두 번째 카드)의 · — 첫 ·는 훈련의 후기
    final dot = find.bySemanticsLabel('·').at(1);

    await tester.tap(dot);
    await tester.pumpAndSettle();
    expect(find.text('사유'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(prefs.getString('rec.jedae2'), isNull);

    await tester.tap(dot);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '휴일');
    await tester.pump(); // 저장 버튼이 켜지게
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('사유: 휴일'), findsOneWidget);
    expect(prefs.getString('rec.jedae2'), '{"6":{"prep":{"main":{"v":"dot","note":"휴일"}}}}');

    await tester.tap(find.bySemanticsLabel('○').at(2));
    await tester.pump();
    expect(find.textContaining('사유:'), findsNothing);
    expect(prefs.getString('rec.jedae2'), '{"6":{"prep":{"main":"o"}}}');
  });

  testWidgets('강사 특별과제의 ·는 사유 없이 바로 골라짐', (tester) async {
    final (_, prefs) = await _pumpApp(tester);
    // · 순서: 훈련 후기, 교재예습, 필독서, 강사 특별과제 …
    await tester.tap(find.bySemanticsLabel('·').at(3));
    await tester.pumpAndSettle();
    expect(find.text('사유'), findsNothing);
    expect(prefs.getString('rec.jedae2'), '{"6":{"task":{"main":"dot"}}}');
  });

  testWidgets('주차 넘기기, 이번 주로 돌아오기, 체크표 줄 누르면 그 주로', (tester) async {
    final (container, _) = await _pumpApp(tester);

    await tester.tap(find.byTooltip('지난 주'));
    await tester.pumpAndSettle();
    expect(find.text('5주차'), findsOneWidget);
    await tester.tap(find.text('이번 주로'));
    await tester.pumpAndSettle();
    expect(find.text('6주차'), findsOneWidget);

    // 체크표 탭: 처음엔 주별 보기, 오늘 주(6주차)부터
    await tester.tap(find.text('체크표'));
    await tester.pumpAndSettle();
    expect(container.read(homeTabProvider), HomeTab.table);
    expect(find.text('6주차'), findsOneWidget);
    await tester.tap(find.byTooltip('지난 주'));
    await tester.pumpAndSettle();
    expect(find.text('5주차'), findsOneWidget);
    await tester.tap(find.text('5주차 체크하러 가기'));
    await tester.pumpAndSettle();
    expect(container.read(homeTabProvider), HomeTab.week);
    expect(find.text('5주차'), findsOneWidget);

    // 표 보기: 주차 줄을 누르면 그 주로
    await tester.tap(find.text('체크표'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('표'));
    await tester.pumpAndSettle();
    expect(find.text('휴강'), findsWidgets);
    await tester.tap(find.text('3주'));
    await tester.pumpAndSettle();
    expect(container.read(homeTabProvider), HomeTab.week);
    expect(find.text('3주차'), findsOneWidget);
  });

  testWidgets('주별 보기: 값을 크게(한 날 수·새벽 점수·지·사유), 비면 –, 보기 방식 기억', (tester) async {
    final rec =
        '{"6":{"attend":{"att":"late"},"prep":{"main":{"v":"dot","note":"휴일"}},'
        '"bible":{"main":31},"dawn":{"main":7}}}';
    final (container, prefs) = await _pumpApp(tester, saved: {LocalStore.recordKey('jedae2'): rec});
    container.read(homeTabProvider.notifier).state = HomeTab.table;
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget); // 성경 5일
    expect(find.text('3'), findsOneWidget); // 새벽기도 3일 (점수는 안 매겨요)
    expect(find.text('지'), findsOneWidget);
    expect(find.text('휴일'), findsOneWidget);
    expect(find.text('–'), findsWidgets);

    await tester.tap(find.text('표'));
    await tester.pumpAndSettle();
    expect(prefs.getString('tableView'), 'grid');
    // 표에서 사유 있는 칸을 누르면 사유
    await tester.tap(find.bySemanticsLabel('·').first);
    await tester.pumpAndSettle();
    expect(find.text('6주 사유'), findsOneWidget);
  });

  // 좁은 화면(Flip 커버 361dp 정도, 아주 좁은 320dp)에서 네 탭 모두 넘침 없이 그려지는지
  for (final width in [361.0, 320.0]) {
    testWidgets('좁은 화면 ${width.toInt()}dp: 네 탭 넘침 없음', (tester) async {
      // 값이 가득 찬 주(금요기도회 세 칸 + 사유)도 넘치지 않는지
      final rec =
          '{"6":{"attend":{"att":"late","review":"o"},"friday":{"att":"o","review":"x",'
          '"pulpit":{"v":"dot","note":"이번 주 강단기도는 담당이 아니었어요"}},"dawn":{"main":3}}}';
      final (container, _) = await _pumpApp(
        tester,
        size: Size(width * 2.7, 700 * 2.7),
        saved: {LocalStore.recordKey('jedae2'): rec},
      );
      for (final tab in HomeTab.values) {
        container.read(homeTabProvider.notifier).state = tab;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab');
      }
      container.read(homeTabProvider.notifier).state = HomeTab.table;
      await tester.pumpAndSettle();
      await tester.tap(find.text('표'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '표 보기');
    });
  }
}
