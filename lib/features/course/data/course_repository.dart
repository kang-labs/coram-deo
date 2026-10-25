import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/course.dart';
import '../../../core/models/course_defaults.dart' show defaultWeekCount;

/// Firestore `courses/{id}` 읽기·쓰기. 읽기는 누구나, 쓰기는 관리자만(firestore.rules).
/// 안드로이드는 오프라인 캐시가 기본으로 켜져 있어서, 한 번 받은 반은 인터넷 없이도 보여요.
class CourseRepository {
  CourseRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('courses');

  /// 앱 전체 설정 문서. `semester` = 지금 학기 번호 (없으면 0).
  DocumentReference<Map<String, dynamic>> get _config => _db.collection('config').doc('app');

  /// 지금 학기 번호. 서버에 문서가 없으면 0, 형식이 다르면 0.
  /// 아직 모르면 null: 오프라인 캐시에 없어서 '없다'고만 나온 경우, 이 폰이 쓴 값을 서버가 아직 확인 안 한 경우.
  /// (모르는 값을 0으로 믿으면 반이 잘못 풀리거나, 관리자가 학기를 거꾸로 돌릴 수 있어요)
  Stream<int?> watchSemester() => _config.snapshots(includeMetadataChanges: true).map((d) {
    if (d.metadata.hasPendingWrites || (!d.exists && d.metadata.isFromCache)) return null;
    final v = d.data()?['semester'];
    return v is num && v.isFinite ? v.toInt() : 0;
  });

  /// 모든 반 (순서대로). 반 수가 적어서 숨김 거르기는 앱에서 해요(복합 색인 없이).
  /// 읽을 수 없는 문서 하나는 건너뛰어요 — 목록 전체가 안 보이는 일이 없게.
  Stream<List<Course>> watchAll() =>
      _col.orderBy('order').snapshots().map((s) => [for (final d in s.docs) ?parseCourse(d.id, d.data())]);

  /// 반 하나. 지워졌거나 읽을 수 없으면 null.
  Stream<Course?> watch(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? parseCourse(d.id, d.data()!) : null);

  /// 문서 하나 읽기. 앞으로 서버 형식이 바뀌어도 앱이 멈추지 않게, 실패하면 null.
  static Course? parseCourse(String id, Map<String, dynamic> data) {
    try {
      return Course.fromMap(id, data);
    } catch (e) {
      debugPrint('반 문서 $id 를 읽지 못해 건너뛰어요: $e');
      return null;
    }
  }

  /// 새 반 id (Firestore 자동 id)
  String newId() => _col.doc().id;

  Future<void> save(Course course) =>
      _col.doc(course.id).set({...course.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setVisible(String id, bool visible) =>
      _col.doc(id).update({'visible': visible, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String id) => _col.doc(id).delete();

  /// 다음 학기 반 만들기: 지금 학기 반마다 기수 +1, 날짜만 비운 사본(사람들에게는 아직 안 보임).
  Future<void> prepareNextSemester(List<Course> current, int nextSemester) {
    final batch = _db.batch();
    for (final c in current) {
      final copy = nextSemesterCopy(c, id: newId(), semester: nextSemester);
      batch.set(_col.doc(copy.id), {...copy.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    }
    return batch.commit();
  }

  /// 새 학기 시작: 학기 번호를 올리고, 새 학기 반은 열고 나머지는 숨겨요.
  /// 예전 앱(학기를 모르는 앱)에서도 새 학기 반만 보이게 visible도 같이 바꿔요.
  Future<void> startSemester(List<Course> all, int semester) {
    final batch = _db.batch();
    for (final c in all) {
      final open = c.semester == semester;
      if (c.visible != open) {
        batch.update(_col.doc(c.id), {'visible': open, 'updatedAt': FieldValue.serverTimestamp()});
      }
    }
    batch.set(_config, {'semester': semester, 'startedAt': FieldValue.serverTimestamp()});
    return batch.commit();
  }

  /// 서버 확인을 [wait]까지만 기다려요. 인터넷이 없으면 Firestore는 폰에 먼저 저장해 두고 연결되면 올리는데,
  /// 그동안 Future가 끝나지 않아서 화면이 멈춘 것처럼 보이기 때문이에요.
  /// 서버가 확인했으면 true, 아직이면(나중에 올라감) false. 권한 오류 등은 그대로 던져요.
  static Future<bool> confirmedWithin(Future<void> write, {Duration wait = const Duration(seconds: 5)}) async {
    try {
      await write.timeout(wait);
      return true;
    } on TimeoutException {
      write.ignore();
      return false;
    }
  }
}

/// 다음 학기 사본: 같은 과정, 기수 +1, 일정 내용은 두고 날짜만 비움, 12주는 채워 둠, 숨김.
Course nextSemesterCopy(Course c, {required String id, required int semester}) {
  final weeks = [for (final w in c.weeks) w.copyWith(date: '')];
  while (weeks.length < defaultWeekCount) {
    weeks.add(const WeekInfo(date: ''));
  }
  return c.copyWith(
    id: id,
    term: '',
    // 새 학기에는 반장·총무를 새로 정해요(지난 권한은 새 반에 없음)
    chief: '',
    treasurer: '',
    cohort: c.cohort > 0 ? c.cohort + 1 : 0,
    semester: semester,
    visible: false,
    weeks: weeks,
    extras: [for (final e in c.extras) e.copyWith(date: '')],
  );
}
