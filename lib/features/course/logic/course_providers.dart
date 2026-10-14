import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../core/models/course.dart';
import '../../record/logic/record_providers.dart';
import '../data/course_repository.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) => CourseRepository(ref.watch(firestoreProvider)));

/// 모든 반 (관리자 화면용, 숨긴 반 포함)
final allCoursesProvider = StreamProvider<List<Course>>((ref) => ref.watch(courseRepositoryProvider).watchAll());

/// 고를 수 있는 반 (보이기 켠 것만)
final visibleCoursesProvider = Provider<AsyncValue<List<Course>>>((ref) {
  return ref
      .watch(allCoursesProvider)
      .whenData(
        (list) => [
          for (final c in list)
            if (c.visible) c,
        ],
      );
});

/// 지금 고른 반. 고른 반이 없거나 지워졌으면 null.
final currentCourseProvider = StreamProvider<Course?>((ref) {
  final id = ref.watch(selectedCourseIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(courseRepositoryProvider).watch(id);
});
