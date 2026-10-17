import 'package:coram_deo/core/local_storage.dart';
import 'package:coram_deo/core/models/course.dart';
import 'package:coram_deo/features/course/data/course_repository.dart';
import 'package:coram_deo/features/course/logic/course_providers.dart';
import 'package:coram_deo/features/course/ui/course_picker_screen.dart';
import 'package:coram_deo/features/record/data/course_record.dart';
import 'package:coram_deo/features/record/logic/record_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_course.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs, {List<Course> server = const []}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      allCoursesProvider.overrideWith((ref) => Stream.value(server)),
      semesterProvider.overrideWith((ref) => Stream.value(0)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('과정·기수·학기: 없으면 기본값, 이상한 값은 건너뜀, 머리글', () {
    final old = Course.fromMap('a', {'name': '양육A반', 'term': '22기 2학기'});
    expect((old.program, old.cohort, old.semester), ('', 0, 0));
    expect(old.groupTitle, '22기 2학기');

    final c = Course.fromMap('b', {'name': '양육A반', 'program': 'yangyuk', 'cohort': 25, 'semester': '3'});
    expect(c.programInfo, Program.yangyuk);
    expect(c.semester, 0); // 글자 값은 기본값
    expect(c.groupTitle, '25기 양육훈련');
    expect(Course.fromMap('c', c.toMap()), c.copyWith(id: 'c'));
    expect(Course.fromMap('d', {'program': 'future'}).groupTitle, '');
  });

  test('다음 학기 사본: 기수 +1, 날짜만 비움, 12주 채움, 숨김', () {
    final src = fakeCourse().copyWith(
      program: 'jedae2',
      cohort: 22,
      semester: 1,
      weeks: fakeCourse().weeks.take(10).toList(),
    );
    final copy = nextSemesterCopy(src, id: 'n', semester: 2);
    expect((copy.id, copy.cohort, copy.semester, copy.visible, copy.term), ('n', 23, 2, false, ''));
    expect(copy.weeks.length, 12);
    expect(copy.weeks.every((w) => w.date.isEmpty), isTrue);
    expect(copy.weeks.first.book, src.weeks.first.book);
    expect(copy.items, src.items);
  });

  test('반 목록 묶기: 과정 순서 → 기수 큰 것 → 반 순서, 모르는 과정은 뒤', () {
    Course c(String id, String program, int cohort, int order) =>
        Course(id: id, name: id, program: program, cohort: cohort, order: order);
    final groups = groupCourses([
      c('d2', 'jedae2', 22, 1),
      c('etc', '', 0, 0),
      c('yB', 'yangyuk', 25, 2),
      c('yA', 'yangyuk', 25, 1),
      c('js', 'jejahak', 24, 1),
    ]);
    expect([for (final g in groups) g.$1], ['25기 양육훈련', '24기 제자학교', '22기 제자대학2학기', '']);
    expect([for (final x in groups.first.$2) x.id], ['yA', 'yB']);
  });

  test('새 학기: 고른 반이 지난 학기 반이면 반 고르기부터, 학기를 모르면 그대로', () async {
    Future<bool> outdated(int? semester, Course? course) async {
      final c = ProviderContainer(
        overrides: [
          semesterProvider.overrideWith((ref) => Stream.value(semester)),
          currentCourseProvider.overrideWith((ref) => Stream.value(course)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(selectedCourseOutdatedProvider, (_, _) {});
      await c.read(semesterProvider.future);
      await c.read(currentCourseProvider.future);
      return c.read(selectedCourseOutdatedProvider);
    }

    final course = fakeCourse().copyWith(semester: 1);
    expect(await outdated(1, course), isFalse);
    expect(await outdated(2, course), isTrue);
    expect(await outdated(null, course), isFalse); // 아직 모름(캐시·확인 전)
    expect(await outdated(2, null), isFalse);
  });

  test('반 고르기 풀기: 고른 반만 지우고 기록은 남김', () async {
    final c = await _container({'courseId': 'jedae2', 'rec.jedae2': '{"1":{"qt":{"main":3}}}'});
    await c.read(selectedCourseIdProvider.notifier).clear();
    expect(c.read(selectedCourseIdProvider), isNull);
    final store = c.read(localStoreProvider);
    expect(store.courseId, isNull);
    expect(store.record('jedae2').isEmpty, isFalse);
  });

  test('반 목록: 학기 번호를 기다렸다가 지금 학기만, 모르면 보이기만', () async {
    final now = fakeCourse().copyWith(id: 'now', semester: 2);
    final old = fakeCourse().copyWith(id: 'old', semester: 1);
    final hidden = fakeCourse().copyWith(id: 'hid', semester: 2, visible: false);
    Future<List<String>?> ids(Stream<int?> sem) async {
      final c = ProviderContainer(
        overrides: [
          semesterProvider.overrideWith((ref) => sem),
          allCoursesProvider.overrideWith((ref) => Stream.value([now, old, hidden])),
        ],
      );
      addTearDown(c.dispose);
      c.listen(visibleCoursesProvider, (_, _) {});
      await c.read(allCoursesProvider.future);
      await Future<void>.delayed(Duration.zero);
      return c.read(visibleCoursesProvider).valueOrNull?.map((x) => x.id).toList();
    }

    expect(await ids(const Stream.empty()), isNull); // 학기 번호를 기다리는 중
    expect(await ids(Stream.value(2)), ['now']);
    expect(await ids(Stream.value(null)), ['now', 'old']);
  });

  test('지난 출석부: 지금 반은 빼고, 사본(없으면 서버 반)으로 보여 줌', () async {
    final snap = fakeCourse().copyWith(id: 'old', program: 'yangyuk', cohort: 24);
    final c = await _container(
      {'courseId': 'now', 'rec.now': '{"1":{"qt":{"main":1}}}', 'rec.old': '{"2":{"qt":{"main":2}}}', 'rec.gone': '{}'},
      server: [fakeCourse().copyWith(id: 'srv')],
    );
    final store = c.read(localStoreProvider);
    await store.saveSnapshot(snap);
    await store.saveRecord('srv', CourseRecord.empty.withValue(1, 'qt', 'main', 4));
    await c.read(allCoursesProvider.future);
    final books = c.read(pastBooksProvider);
    expect({for (final b in books) b.course.id}, {'old', 'srv'});
    final old = books.firstWhere((b) => b.course.id == 'old');
    expect(old.course.groupTitle, '24기 양육훈련');
    expect(old.record.mask(2, 'qt', 'main'), 2);
  });
}
