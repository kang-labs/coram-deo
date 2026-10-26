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

  /// 새 학기가 시작돼서 반 고르기부터 다시. 하던 반 기록·사본은 그대로 남아 지난 출석부로 가요.
  Future<void> clear() async {
    if (state == null) return;
    state = null;
    await ref.read(localStoreProvider).clearCourseId();
  }
}

/// 지난 출석부처럼 보기만 하는 화면이면 true (체크하러 가기 버튼·줄 누르기를 막아요)
final recordReadOnlyProvider = Provider<bool>((ref) => false);

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
  /// [note]는 · 같은 값의 사유. 다른 값으로 바꾸면 사유는 지워져요.
  void setValue(int week, String itemId, String partId, Object? value, {String? note}) {
    final id = _courseId;
    if (id == null || state.entry(week, itemId, partId) == (value: value, note: note)) return;
    final next = state.withValue(week, itemId, partId, value, note: note);
    state = next;
    ref.read(localStoreProvider).saveRecord(id, next);
  }

  /// 빈 칸만 [other]로 채우고 저장해요 (관리자가 돌려준 예전 기록). 고른 반이 [courseId]가 아니면 아무것도 안 해요.
  Future<void> fillFrom(String courseId, CourseRecord other) async {
    if (_courseId != courseId) return;
    final next = state.fillFrom(other);
    if (next == state) return;
    state = next;
    await ref.read(localStoreProvider).saveRecord(courseId, next);
  }
}
