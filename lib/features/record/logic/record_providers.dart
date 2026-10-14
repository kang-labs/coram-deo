import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_storage.dart';
import '../data/course_record.dart';
import '../data/local_store.dart';

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

/// 고른 반 id (없으면 처음 실행 → 반 고르기 화면)
final selectedCourseIdProvider = NotifierProvider<SelectedCourseController, String?>(SelectedCourseController.new);

class SelectedCourseController extends Notifier<String?> {
  @override
  String? build() => ref.watch(localStoreProvider).courseId;

  Future<void> select(String id) async {
    if (id == state) return;
    state = id;
    await ref.read(localStoreProvider).setCourseId(id);
  }
}

/// 내 이름 (체크표 위에 표시)
final myNameProvider = NotifierProvider<MyNameController, String>(MyNameController.new);

class MyNameController extends Notifier<String> {
  @override
  String build() => ref.watch(localStoreProvider).name;

  Future<void> set(String name) async {
    state = name.trim();
    await ref.read(localStoreProvider).setName(state);
  }
}

/// 지금 고른 반의 내 체크 기록. 반을 바꾸면 그 반 기록을 읽어요(기록은 반마다 따로).
///
/// 화면에서는 칸 하나만 `select`로 watch 해서, 체크 하나에 그 칸만 다시 그립니다.
final courseRecordProvider = NotifierProvider<CourseRecordController, CourseRecord>(CourseRecordController.new);

class CourseRecordController extends Notifier<CourseRecord> {
  String? _courseId;

  @override
  CourseRecord build() {
    _courseId = ref.watch(selectedCourseIdProvider);
    final id = _courseId;
    return id == null ? CourseRecord.empty : ref.watch(localStoreProvider).record(id);
  }

  /// [week]주차(1부터) 칸 값 바꾸기. 바로 저장해요.
  void setValue(int week, String itemId, int part, Object? value) {
    final id = _courseId;
    if (id == null) return;
    final next = state.withValue(week, itemId, part, value);
    if (next == state) return;
    state = next;
    ref.read(localStoreProvider).saveRecord(id, next);
  }
}
