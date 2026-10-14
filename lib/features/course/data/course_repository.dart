import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/course.dart';

/// Firestore `courses/{id}` 읽기·쓰기. 읽기는 누구나, 쓰기는 관리자만(firestore.rules).
/// 안드로이드는 오프라인 캐시가 기본으로 켜져 있어서, 한 번 받은 반은 인터넷 없이도 보여요.
class CourseRepository {
  CourseRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('courses');

  /// 모든 반 (순서대로). 반 수가 적어서 숨김 거르기는 앱에서 해요(복합 색인 없이).
  Stream<List<Course>> watchAll() =>
      _col.orderBy('order').snapshots().map((s) => [for (final d in s.docs) Course.fromMap(d.id, d.data())]);

  /// 반 하나. 지워졌으면 null.
  Stream<Course?> watch(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? Course.fromMap(d.id, d.data()!) : null);

  /// 새 반 id (Firestore 자동 id)
  String newId() => _col.doc().id;

  Future<void> save(Course course) =>
      _col.doc(course.id).set({...course.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setVisible(String id, bool visible) =>
      _col.doc(id).update({'visible': visible, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String id) => _col.doc(id).delete();
}
