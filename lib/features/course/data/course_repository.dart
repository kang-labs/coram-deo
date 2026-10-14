import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/course.dart';

/// Firestore `courses/{id}` 읽기·쓰기. 읽기는 누구나, 쓰기는 관리자만(firestore.rules).
/// 안드로이드는 오프라인 캐시가 기본으로 켜져 있어서, 한 번 받은 반은 인터넷 없이도 보여요.
class CourseRepository {
  CourseRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('courses');

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
