import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../core/models/course.dart';
import '../../record/data/course_record.dart';
import '../../record/logic/record_providers.dart';
import '../data/course_repository.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) => CourseRepository(ref.watch(firestoreProvider)));

/// 관리자가 쓰기에 쓰는 저장소 (관리자 전용 Firebase 앱 = 관리자 로그인 권한으로 저장)
final adminCourseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(adminFirestoreProvider)),
);

/// 모든 반 (관리자 화면용, 숨긴 반·지난 학기 포함)
final allCoursesProvider = StreamProvider<List<Course>>((ref) => ref.watch(courseRepositoryProvider).watchAll());

/// 지금 학기 번호 (관리자가 '새 학기 시작하기'를 누를 때마다 1씩 올라가요). 아직 모르면 null.
final semesterProvider = StreamProvider<int?>((ref) => ref.watch(courseRepositoryProvider).watchSemester());

/// 고를 수 있는 반: 지금 학기 + 보이기 켠 것만.
/// 학기 번호를 처음 받는 중이면 기다리고, 끝내 모르면(오프라인·오류) 보이기만 봐요(예전 앱과 같게).
final visibleCoursesProvider = Provider<AsyncValue<List<Course>>>((ref) {
  final sem = ref.watch(semesterProvider);
  if (sem.isLoading && !sem.hasValue) return const AsyncLoading();
  final semester = sem.valueOrNull;
  return ref
      .watch(allCoursesProvider)
      .whenData(
        (list) => [
          for (final c in list)
            if (c.visible && (semester == null || c.semester == semester)) c,
        ],
      );
});

/// 고른 반이 지난 학기 반인지 (관리자가 새 학기를 시작했으면 true → 반 고르기부터 다시).
/// 반 문서의 학기는 바뀌지 않으므로, 늦게 업데이트한 폰도 이걸로 알아차려요.
final selectedCourseOutdatedProvider = Provider<bool>((ref) {
  final semester = ref.watch(semesterProvider).valueOrNull;
  final course = ref.watch(currentCourseProvider).valueOrNull;
  return semester != null && course != null && course.semester < semester;
});

/// 지금 고른 반. 고른 반이 없거나 지워졌으면 null.
/// 받을 때마다 폰에 사본을 남겨서, 나중에 지난 출석부로 볼 수 있게 해요.
final currentCourseProvider = StreamProvider<Course?>((ref) {
  final id = ref.watch(selectedCourseIdProvider);
  if (id == null) return Stream.value(null);
  final store = ref.watch(localStoreProvider);
  return ref.watch(courseRepositoryProvider).watch(id).map((c) {
    if (c != null) store.saveSnapshot(c);
    return c;
  });
});

/// 지난 출석부 한 권 (반 사본 + 내 기록)
typedef PastBook = ({Course course, CourseRecord record});

/// 지난 출석부: 기록이 있는 반 중 지금 반이 아닌 것. 최근 학기·기수 먼저.
/// 사본이 없는 예전 기록은 서버에 반이 남아 있으면 그걸로 보여요.
final pastBooksProvider = Provider.autoDispose<List<PastBook>>((ref) {
  final store = ref.watch(localStoreProvider);
  final current = ref.watch(selectedCourseIdProvider);
  final server = {for (final c in ref.watch(allCoursesProvider).valueOrNull ?? const <Course>[]) c.id: c};
  final books = <PastBook>[
    for (final id in store.recordCourseIds())
      if (id != current)
        if (store.snapshot(id) ?? server[id] case final course?) (course: course, record: store.record(id)),
  ];
  books.sort((a, b) {
    final s = b.course.semester.compareTo(a.course.semester);
    return s != 0 ? s : b.course.cohort.compareTo(a.course.cohort);
  });
  return books;
});
