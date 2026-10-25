import 'package:coram_deo/app/app.dart';
import 'package:coram_deo/app/theme.dart';
import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/features/course/data/course_repository.dart';
import 'package:coram_deo/features/course/logic/course_providers.dart';
import 'package:coram_deo/features/record/data/course_record.dart';
import 'package:coram_deo/features/roster/data/roster_repository.dart';
import 'package:coram_deo/features/roster/logic/roster_providers.dart';
import 'package:coram_deo/features/roster/ui/roster_view.dart';
import 'package:coram_deo/features/week/logic/week_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_course.dart';

class _FixedToday extends TodayController {
  @override
  DateTime build() => DateTime.utc(2026, 10, 14); // 제자대학2학기 6주차
}

Member _m(String uid, String name, int minute, [CourseRecord record = CourseRecord.empty]) =>
    Member(uid: uid, name: name, record: record, updatedAt: DateTime(2026, 10, 1, 0, minute));

void main() {
  test('반장·총무 이름: 서버 형식 읽기·쓰기, 띄어쓰기 무시, 새 학기 사본은 비움', () {
    final c = Course.fromMap('a', {
      'name': '양육A반',
      'leaders': {'chief': '홍 길동A', 'treasurer': '김영희'},
    });
    expect((c.chief, c.treasurer), ('홍 길동A', '김영희'));
    expect(c.isLeaderName('홍길동A'), isTrue);
    expect(c.isLeaderName(' 김 영희 '), isTrue);
    expect(c.isLeaderName('홍길동'), isFalse);
    expect(c.isLeaderName('홍길동a'), isTrue); // 영문 대소문자 무시
    expect(normalizeName('홍 길동a	'), '홍길동A');
    expect(c.isLeaderName(''), isFalse);
    expect(Course.fromMap('a', c.toMap()), c);
    expect(Course.fromMap('b', {'name': 'x', 'leaders': 'bad'}).chief, '');
    final next = nextSemesterCopy(c, id: 'n', semester: 1);
    expect((next.chief, next.treasurer), ('', ''));
  });

  test('반 사람: 같은 이름은 최근 것만, 이름 가나다순', () {
    final list = latestByName([_m('1', '이순신', 1), _m('2', '강감찬', 2), _m('3', '이 순신', 5), _m('4', '김유신', 3)]);
    expect([for (final m in list) m.name], ['강감찬', '김유신', '이 순신']);
    expect(list.last.uid, '3');
    expect(Member.fromDoc('x', {'name': '  '}), isNull);
    expect(Member.fromDoc('x', {'name': '홍길동', 'record': 'bad'})!.record, CourseRecord.empty);
  });

  testWidgets('처음 실행: 이름을 적어야 반 고르기로 넘어감', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCoursesProvider.overrideWith((ref) => Stream.value([fakeCourse()])),
          semesterProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: const CoramDeoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A·B·C'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다음'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  홍길동A ');
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(prefs.getString('name'), '홍길동A');
    expect(find.text('제자대학2학기'), findsWidgets);
  });

  testWidgets('출석부: 고른 주의 사람들 가나다순, 주차 넘기기, 저장 버튼은 관리자만', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final members = latestByName([
      _m('1', '이순신', 1, CourseRecord.empty.withValue(6, 'attend', 'att', 'o')),
      _m('2', '강감찬', 2),
    ]);
    Future<void> pump(bool canSave) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [todayProvider.overrideWith(_FixedToday.new)],
          child: MaterialApp(
            theme: AppTheme.of(AppThemeId.fallback),
            home: Scaffold(
              body: RosterView(course: fakeCourse(), members: AsyncData(members), canSave: canSave),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(false);
    expect(find.text('6주차'), findsOneWidget);
    final kang = tester.getTopLeft(find.text('강감찬')).dy;
    final lee = tester.getTopLeft(find.text('이순신')).dy;
    expect(kang, lessThan(lee));
    expect(find.textContaining('이미지로 저장'), findsNothing);
    await tester.tap(find.byTooltip('다음 주'));
    await tester.pumpAndSettle();
    expect(find.text('7주차'), findsOneWidget);

    await pump(true);
    expect(find.textContaining('출석부 이미지로 저장'), findsOneWidget);
  });

  test('반장·총무 코드 물을 때: 이름이 지정됐고, 아직 인정 안 됐을 때만', () async {
    Future<bool> needed({required String name, required bool leader}) async {
      SharedPreferences.setMockInitialValues({'name': name, 'courseId': 'jedae2'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentCourseProvider.overrideWith(
            (ref) => Stream.value(fakeCourse().copyWith(chief: '홍길동A', treasurer: '김영희')),
          ),
          isLeaderProvider.overrideWith((ref) => Stream.value(leader)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(leaderCodeNeededProvider, (_, _) {});
      await c.read(currentCourseProvider.future);
      await c.read(isLeaderProvider.future);
      return c.read(leaderCodeNeededProvider);
    }

    expect(await needed(name: '홍 길동A', leader: false), isTrue);
    expect(await needed(name: '홍길동A', leader: true), isFalse);
    expect(await needed(name: '이순신', leader: false), isFalse);
  });
}
