import 'package:coram_deo/app/app.dart';
import 'package:coram_deo/app/layout.dart';
import 'package:coram_deo/app/theme.dart';
import 'package:coram_deo/core/device_kind.dart';
import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/features/admin/ui/leaders_sheet.dart';
import 'package:coram_deo/features/course/data/course_repository.dart';
import 'package:coram_deo/features/course/logic/course_providers.dart';
import 'package:coram_deo/features/record/data/course_record.dart';
import 'package:coram_deo/features/roster/data/roster_repository.dart';
import 'package:coram_deo/features/roster/logic/roster_providers.dart';
import 'package:coram_deo/features/roster/ui/member_sheet.dart';
import 'package:coram_deo/features/roster/ui/roster_view.dart';
import 'package:coram_deo/features/roster/ui/users_screen.dart';
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
  test('반장·총무(예전 반, 이름만): 서버 형식 읽기·쓰기, 띄어쓰기 무시, 새 학기 사본은 비움', () {
    final c = Course.fromMap('a', {
      'name': '양육A반',
      'leaders': {'chief': '홍 길동A', 'treasurer': '김영희'},
    });
    expect((c.chief, c.treasurer, c.chiefUid, c.treasurerUid), ('홍 길동A', '김영희', '', ''));
    expect(c.leaderRole('u1', '홍길동A'), '반장');
    expect(c.leaderRole('u1', ' 김 영희 '), '총무');
    expect(c.leaderRole('u1', '홍길동'), isNull);
    expect(c.leaderRole('u1', '홍길동a'), '반장'); // 영문 대소문자 무시
    expect(normalizeName('홍 길동a	'), '홍길동A');
    expect(c.leaderRole('u1', ''), isNull);
    expect(Course.fromMap('a', c.toMap()), c);
    expect(Course.fromMap('b', {'name': 'x', 'leaders': 'bad'}).chief, '');
    final next = nextSemesterCopy(c, id: 'n', semester: 1);
    expect((next.chief, next.treasurer), ('', ''));
  });

  test('반장·총무(출석부에서 고른 반): uid로만 보고, 같은 이름의 다른 폰은 아님', () {
    final c = Course.fromMap('a', {
      'name': '양육A반',
      'leaders': {'chief': '홍길동A', 'treasurer': '', 'chiefUid': 'u1', 'treasurerUid': ''},
    });
    expect(c.leaderRole('u1', '아무이름'), '반장');
    expect(c.leaderRole('u2', '홍길동A'), isNull); // 앱을 다시 깐 폰·동명이인
    expect(c.leaderRole('', '홍길동A'), isNull);
    expect(Course.fromMap('a', c.toMap()), c);
    final next = nextSemesterCopy(c, id: 'n', semester: 1);
    expect((next.chiefUid, next.treasurerUid), ('', ''));
  });

  test('양육국: 여럿, uid로 보고, 서버 형식 읽기·쓰기, 모양이 다른 줄은 건너뜀, 새 학기 사본은 비움', () {
    final c = Course.fromMap('a', {
      'name': '양육A반',
      'leaders': {
        'chief': '',
        'treasurer': '',
        'chiefUid': '',
        'treasurerUid': '',
        'staff': [
          {'uid': 's1', 'name': '박목사'},
          {'uid': 's2', 'name': '최전도사'},
          {'name': 'uid 없음'},
          'bad',
        ],
      },
    });
    expect([for (final s in c.staff) s.uid], ['s1', 's2']);
    expect(c.leaderRole('s2', '아무이름'), '양육국');
    expect(c.leaderRole('x', '박목사'), isNull);
    expect(Course.fromMap('a', c.toMap()), c);
    expect(nextSemesterCopy(c, id: 'n', semester: 1).staff, isEmpty);
  });

  test('반 사람: 같은 이름은 최근 것만, 이름 가나다순', () {
    final list = latestByName([_m('1', '이순신', 1), _m('2', '강감찬', 2), _m('3', '이 순신', 5), _m('4', '김유신', 3)]);
    expect([for (final m in list) m.name], ['강감찬', '김유신', '이 순신']);
    expect(list.last.uid, '3');
    expect(Member.fromDoc('x', {'name': '  '}), isNull);
    expect(Member.fromDoc('x', {'name': '홍길동', 'record': 'bad'})!.record, CourseRecord.empty);
  });

  test('출석부 순서: 반장 → 총무 → 가나다순, 역할 글', () {
    final course = fakeCourse().copyWith(chief: '홍 길동a', treasurer: '김영희');
    final rows = rosterOrder([_m('1', '이순신', 1), _m('2', '김영희', 2), _m('3', '강감찬', 3), _m('4', '홍길동A', 4)], course);
    expect([for (final r in rows) r.member.name], ['홍길동A', '김영희', '강감찬', '이순신']);
    expect([for (final r in rows) r.role], ['반장', '총무', null, null]);
  });

  test('출석부 순서: 출석부에서 고른 반은 uid로 역할 표시', () {
    final course = fakeCourse().copyWith(chief: '강감찬', chiefUid: '3', treasurerUid: '1', treasurer: '이순신');
    final rows = rosterOrder([_m('1', '이순신', 1), _m('2', '강감찬', 2), _m('3', '김유신', 3)], course);
    expect([for (final r in rows) (r.member.uid, r.role)], [('3', '반장'), ('1', '총무'), ('2', null)]);
  });

  test('출석부 순서: 양육국은 앞으로 올리지 않고 가나다순, 역할 글만', () {
    final course = fakeCourse().copyWith(
      chiefUid: '4',
      chief: '홍길동',
      staff: const [StaffRef(uid: '1', name: '가나다')],
    );
    final rows = rosterOrder([_m('1', '가나다', 1), _m('2', '강감찬', 2), _m('3', '나무', 3), _m('4', '홍길동', 4)], course);
    expect(
      [for (final r in rows) (r.member.name, r.role)],
      [('홍길동', '반장'), ('가나다', '양육국'), ('강감찬', null), ('나무', null)],
    );
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

  testWidgets('출석부는 보기만: 번호 안 보이고 이름 눌러도 창 없음', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final members = latestByName([
      _m('newUid1234', '이순신', 9),
      _m('oldUid5678', '이순신', 1, CourseRecord.empty.withValue(6, 'attend', 'att', 'o')),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [todayProvider.overrideWith(_FixedToday.new)],
        child: MaterialApp(
          theme: AppTheme.of(AppThemeId.fallback),
          home: Scaffold(
            body: RosterView(course: fakeCourse(), members: AsyncData(members), canSave: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이순신'));
    await tester.pumpAndSettle();
    expect(find.textContaining('지울까요'), findsNothing);
    expect(find.textContaining('보기만 할 수 있어요'), findsOneWidget);
    expect(find.textContaining('newUid'), findsNothing);
    expect(find.textContaining('예전'), findsNothing);
  });

  test('사용자 관리: 이름순·반 순서, 이름 찾기, 가져올 기록 후보(같은 이름 먼저, 빈 기록·본인 빼기)', () {
    final rec = CourseRecord.empty.withValue(1, 'attend', 'att', 'o');
    final a = fakeCourse().copyWith(order: 2);
    final b = fakeCourse().copyWith(order: 1);
    final users = sortUsers([
      (course: a, member: _m('1', '이순신', 1), phoneCid: null),
      (course: a, member: _m('2', '강감찬', 1), phoneCid: null),
      (course: b, member: _m('3', '이순신', 1), phoneCid: null),
    ]);
    expect([for (final u in users) u.member.uid], ['2', '3', '1']);
    expect(nameMatches('홍 길동A', '길동a'), isTrue);
    expect(nameMatches('홍길동', '이순'), isFalse);
    expect(nameMatches('홍길동', ' '), isTrue);

    final members = latestByName([
      _m('new', '홍길동', 9),
      _m('old', '홍 길동', 1, rec),
      _m('empty', '홍길동', 0),
      _m('kim', '김철수', 5, rec),
      _m('ahn', '안창호', 5, rec),
    ]);
    final target = members.firstWhere((m) => m.uid == 'new');
    final c = importCandidates(members, target);
    expect([for (final d in c.sameName) d.uid], ['old']);
    expect([for (final d in c.others) d.uid], ['kim', 'ahn']);
  });

  testWidgets('사용자 관리 화면 320dp: 반 이름 옆에, 찾기, 긴 반 이름도 넘침 없음', (tester) async {
    tester.view.physicalSize = const Size(320 * 2.7, 2000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final long = fakeCourse().copyWith(id: 'long', name: '아주아주긴이름의제자대학훈련과정2학기반');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          adminUsersProvider.overrideWith(
            (ref) async => sortUsers([
              (course: long, member: _m('1', '홍길동가나다라마바사아자차카타파하', 1), phoneCid: 'other'),
              (
                course: fakeCourse(),
                member: Member(uid: '2', name: '김철수', record: CourseRecord.empty, device: DeviceKind.iphone),
                phoneCid: null,
              ),
            ]),
          ),
        ],
        child: MaterialApp(theme: AppTheme.of(AppThemeId.fallback), home: const UsersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('제자대학2학기'), findsOneWidget);
    expect(find.textContaining('2명'), findsOneWidget);
    expect(find.textContaining('아이폰 · '), findsOneWidget);
    expect(DeviceKind.fromCode('android'), DeviceKind.android);
    expect(DeviceKind.fromCode('x'), isNull);
    await tester.enterText(find.byType(TextField), '철수');
    await tester.pumpAndSettle();
    expect(find.text('김철수'), findsOneWidget);
    expect(find.textContaining('홍길동'), findsNothing);

    // 반별 보기: 반 이름(사람 수) 머리글, 줄에는 반 배지 없음, 고른 방식 기억
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('반별'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('제자대학2학기 · 1명'), findsOneWidget);
    expect(find.text('아주아주긴이름의제자대학훈련과정2학기반 · 1명'), findsOneWidget);
    expect(find.text('제자대학2학기'), findsNothing);
    expect(prefs.getString('usersView'), 'byCourse');
  });

  testWidgets('목록 여백: 하단 시스템 바 높이를 더해요', (tester) async {
    late EdgeInsets pad;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
        child: Builder(
          builder: (context) {
            pad = AppLayout.listPadding(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(pad.bottom, 24 + 48);
    expect(pad.left, AppLayout.sidePadding);
  });

  testWidgets('사용자 관리 창: 데이터 가져와 주기 → 같은 이름 먼저·이름 찾기 → 확인 창, 지우기 확인 창', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final rec = CourseRecord.empty.withValue(1, 'attend', 'att', 'o');
    final members = latestByName([_m('new', '이순신', 9), _m('old', '이순신', 1, rec), _m('kim', '김철수', 5, rec)]);
    final target = members.firstWhere((m) => m.uid == 'new');
    final other = fakeCourse().copyWith(id: 'jedae1', name: '제자대학1학기');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleCoursesProvider.overrideWithValue(AsyncData([fakeCourse(), other])),
        ],
        child: MaterialApp(
          theme: AppTheme.of(AppThemeId.fallback),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMemberSheet(context, fakeCourse(), target, members),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('같은 이름 예전 기록 1개'), findsOneWidget);
    expect(find.textContaining('newUid'), findsNothing);

    await tester.tap(find.text('데이터 가져와 주기'));
    await tester.pumpAndSettle();
    expect(find.text('같은 이름 기록'), findsOneWidget);
    expect(find.text('다른 이름 기록'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '철수');
    await tester.pumpAndSettle();
    expect(find.text('같은 이름 기록'), findsNothing);
    await tester.tap(find.text('김철수'));
    await tester.pumpAndSettle();
    expect(find.text('기록을 가져와 줄까요?'), findsOneWidget);
    expect(find.textContaining('이름이 달라요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('반 옮기기'));
    await tester.pumpAndSettle();
    expect(find.text('이순신 님을 옮길 반'), findsOneWidget);
    expect(find.text('제자대학2학기'), findsNothing); // 지금 반은 빼요
    await tester.tap(find.text('제자대학1학기'));
    await tester.pumpAndSettle();
    expect(find.text('이순신 님 반을 옮길까요?'), findsOneWidget);
    expect(find.textContaining('같은 이름 예전 기록 1개도'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('출석부에서 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('이순신 님을 출석부에서 지울까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('지울까요'), findsNothing);
  });

  test('반 옮기기: 새 반에 있는 칸만, 칸 종류에 맞는 값만, 그 반 주 수까지 들고 가요', () {
    final rec = CourseRecord.empty
        .withValue(1, 'attend', 'att', 'late')
        .withValue(1, 'attend', 'review', 'dot', note: '휴일')
        .withValue(1, 'zzz', 'main', 'o') // 새 반에 없는 항목
        .withValue(2, 'prep', 'main', 'late') // 고르는 칸에 없는 값
        .withValue(2, 'bible', 'main', 127)
        .withValue(13, 'attend', 'att', 'o'); // 12주 반에 없는 주
    final kept = rec.onlyFor(fakeCourse());
    expect(kept.value(1, 'attend', 'att'), 'late');
    expect(kept.note(1, 'attend', 'review'), '휴일');
    expect(kept.value(1, 'zzz', 'main'), isNull);
    expect(kept.value(2, 'prep', 'main'), isNull);
    expect(kept.mask(2, 'bible', 'main'), 127);
    expect(kept.weekCount, 2);
    final noAttend = fakeCourse().copyWith(
      items: [
        for (final i in fakeCourse().items)
          if (i.id != 'attend') i,
      ],
    );
    expect(rec.onlyFor(noAttend).value(1, 'attend', 'att'), isNull);
  });

  test('같은 이름 예전 문서는 older에 최근 것 먼저, 기록 합치기는 빈 칸만', () {
    final a = CourseRecord.empty.withValue(1, 'attend', 'att', 'o');
    final b = CourseRecord.empty.withValue(1, 'attend', 'att', 'x').withValue(2, 'attend', 'att', 'late');
    final list = latestByName([_m('old', '홍길동', 1, b), _m('new', '홍길동', 9, a), _m('mid', '홍 길동', 5)]);
    expect(list.single.uid, 'new');
    expect([for (final o in list.single.older) o.uid], ['mid', 'old']);
    final merged = a.fillFrom(b);
    expect(merged.value(1, 'attend', 'att'), 'o'); // 이미 체크한 칸은 그대로
    expect(merged.value(2, 'attend', 'att'), 'late'); // 빈 칸만 채움
    expect(merged.weekCount, 2);
    expect(a.fillFrom(CourseRecord.empty), a);
  });

  testWidgets('반장·총무 고르기: 출석부 사람 목록, 예전 반은 같은 이름으로 미리 고름, 출석부에 없으면 알림', (tester) async {
    final course = fakeCourse().copyWith(chief: '홍 길동a', treasurer: '박철수');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminClassMembersProvider(course.id)
              .overrideWith((ref) => Stream.value([_m('1', '이순신', 1), _m('2', '홍길동A', 2)])),
        ],
        child: MaterialApp(
          theme: AppTheme.of(AppThemeId.fallback),
          home: Scaffold(body: LeadersForm(course: course)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('홍길동A'), findsOneWidget); // 반장 칸에 미리 골라짐
    expect(find.text('없음'), findsOneWidget); // 총무는 출석부에 없어서 비움
    expect(find.textContaining('총무 박철수 님은 출석부에 없어서'), findsOneWidget);
    await tester.tap(find.text('없음'));
    await tester.pumpAndSettle();
    expect(find.text('이순신'), findsWidgets); // 펼친 목록에 출석부 사람
  });
}
