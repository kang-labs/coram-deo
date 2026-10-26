import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/course.dart';
import '../../record/data/course_record.dart';

/// 반 사람 한 명의 출석부 (서버 `courses/{반}/members/{익명 uid}`)
@immutable
class Member {
  const Member({required this.uid, required this.name, required this.record, this.updatedAt, this.older = const []});

  final String uid;
  final String name;
  final CourseRecord record;
  final DateTime? updatedAt;

  /// 같은 이름으로 남은 예전 문서들 (최근 것 먼저). 앱을 다시 깔았거나 동명이인일 때 생겨요.
  final List<Member> older;

  Member withOlder(List<Member> older) =>
      Member(uid: uid, name: name, record: record, updatedAt: updatedAt, older: older);

  /// 서버 문서 하나. 모양이 다르면 null(건너뜀).
  static Member? fromDoc(String uid, Map<String, dynamic> m) {
    final name = m['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final u = m['updatedAt'];
    return Member(
      uid: uid,
      name: name.trim(),
      record: m['record'] is Map ? CourseRecord.fromJson(jsonEncode(m['record'])) : CourseRecord.empty,
      updatedAt: u is Timestamp ? u.toDate() : null,
    );
  }
}

/// 같은 이름(띄어쓰기 무시)은 가장 최근 것만 남기고 이름 가나다순으로. 나머지는 [Member.older]에 담아요.
/// 앱을 다시 깔면 익명 uid가 바뀌어 같은 사람 문서가 둘이 될 수 있어서예요.
List<Member> latestByName(Iterable<Member> members) {
  final byName = <String, List<Member>>{};
  for (final m in members) {
    byName.putIfAbsent(normalizeName(m.name), () => []).add(m);
  }
  DateTime at(Member m) => m.updatedAt ?? DateTime(0);
  return [
    for (final group in byName.values)
      (group..sort((a, b) => at(b).compareTo(at(a)))).first.withOlder(List.unmodifiable(group.skip(1))),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// 익명 로그인 번호 앞 6자리 (동명이인을 구별하려고 작게 보여 줘요)
String shortUid(String uid) => uid.length <= 6 ? uid : uid.substring(0, 6);

/// 출석부 순서: 반장 → 총무 → 나머지 이름 가나다순. 반장·총무 줄 이름 아래에 보일 역할 글도 같이.
List<({Member member, String? role})> rosterOrder(List<Member> members, Course course) {
  String? roleOf(Member m) {
    final n = normalizeName(m.name);
    if (n.isEmpty) return null;
    if (n == normalizeName(course.chief)) return '반장';
    if (n == normalizeName(course.treasurer)) return '총무';
    return null;
  }

  int rank(String? role) => switch (role) {
    '반장' => 0,
    '총무' => 1,
    _ => 2,
  };
  final rows = [for (final m in members) (member: m, role: roleOf(m))];
  rows.sort((a, b) {
    final r = rank(a.role).compareTo(rank(b.role));
    return r != 0 ? r : a.member.name.compareTo(b.member.name);
  });
  return rows;
}

/// 반 사람 기록 올리기·보기, 반장·총무 코드
class RosterRepository {
  RosterRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _course(String cid) => _db.collection('courses').doc(cid);

  /// 내 기록 올리기 (익명 uid 자리). 기록이 비어도 이름은 올려서 반장 출석부에 보이게 해요.
  Future<void> upload(String cid, String uid, String name, CourseRecord record) =>
      _course(cid)
          .collection('members')
          .doc(uid)
          .set({'name': name, 'record': jsonDecode(record.toJson()), 'updatedAt': FieldValue.serverTimestamp()});

  /// 내 문서 지우기 (반을 잘못 골랐다 바꿀 때, 기록이 비어 있을 때만 앱이 불러요)
  Future<void> removeMine(String cid, String uid) => _course(cid).collection('members').doc(uid).delete();

  DocumentReference<Map<String, dynamic>> _restore(String cid, String uid) =>
      _course(cid).collection('restores').doc(uid);

  /// 관리자가 돌려준 예전 기록 (없으면 null). 오프라인 캐시로 판단하지 않게 서버에서만 읽어요(실패하면 예외).
  Future<CourseRecord?> readRestore(String cid, String uid) async {
    final d = await _restore(cid, uid).get(const GetOptions(source: Source.server));
    final r = d.data()?['record'];
    return d.exists ? (r is Map ? CourseRecord.fromJson(jsonEncode(r)) : CourseRecord.empty) : null;
  }

  /// 돌려받은 기록을 폰에 합친 뒤 상자를 비워요
  Future<void> clearRestore(String cid, String uid) => _restore(cid, uid).delete();

  /// 서버에 내 문서가 아직 있는지. 오프라인 캐시로 잘못 판단하지 않게 서버에서만 읽어요(실패하면 예외).
  Future<bool> mineExists(String cid, String uid) async =>
      (await _course(cid).collection('members').doc(uid).get(const GetOptions(source: Source.server))).exists;

  /// 반 사람 전부 (반장·총무·관리자만 읽을 수 있어요)
  Stream<List<Member>> watchMembers(String cid) =>
      _course(cid)
          .collection('members')
          .snapshots()
          .map((s) => latestByName([for (final d in s.docs) ?Member.fromDoc(d.id, d.data())]));

  /// 관리자 화면: 반 기록을 미리 한 번 받아 폰 캐시에 넣어 둬요. 출석부를 열 때 캐시가 먼저 바로 보여요.
  Future<void> prefetchMembers(String cid) async {
    try {
      await _course(cid).collection('members').get();
    } catch (_) {
      // 미리 받기는 실패해도 괜찮아요(열 때 다시 받아요)
    }
  }

  /// 이 폰(uid)이 이 반 반장·총무로 인정됐는지
  Stream<bool> watchIsLeader(String cid, String uid) =>
      _course(cid).collection('leaders').doc(uid).snapshots().map((d) => d.exists);

  /// 반장·총무 코드 넣기. 이름과 코드가 맞으면(서버 규칙이 확인) true.
  Future<bool> claimLeader(String cid, String uid, String name, String code) async {
    try {
      await _course(cid)
          .collection('leaders')
          .doc(uid)
          .set({'name': normalizeName(name), 'code': code, 'at': FieldValue.serverTimestamp()});
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  // ── 관리자 ──

  DocumentReference<Map<String, dynamic>> _codes(String cid) => _course(cid).collection('private').doc('codes');

  /// 출석부에서 사람 지우기. 이 이름(띄어쓰기·대소문자 무시)으로 올라온 문서를 모두 지워요.
  /// 앱을 다시 깔아 생긴 옛 문서도 같이 지워야 옛 기록이 대신 나타나지 않아요. 반장·총무 인정도 같이 풀어요.
  /// 오프라인 캐시에 없는 문서를 놓치지 않게 서버에서 읽어요. 지운 문서 수를 돌려줘요.
  Future<int> removeMembersNamed(String cid, String name) async {
    final key = normalizeName(name);
    final docs = await _course(cid).collection('members').get(const GetOptions(source: Source.server));
    final batch = _db.batch();
    var count = 0;
    for (final d in docs.docs) {
      final v = d.data()['name'];
      if (v is! String || normalizeName(v) != key) continue;
      batch.delete(d.reference);
      batch.delete(_course(cid).collection('leaders').doc(d.id));
      count++;
    }
    if (count > 0) await batch.commit();
    return count;
  }

  /// 관리자: 같은 이름 예전 문서들의 기록을 [to]의 폰에 돌려줘요. 그 폰이 다음에 앱을 열면 빈 칸만 채워요.
  /// 예전 기록(최근 것 먼저)을 하나로 합치고, 아직 안 가져간 돌려주기가 있으면 그것도 합쳐요.
  /// 한 번에(batch) 돌려주기 상자를 채우고 예전 문서와 그 반장·총무 인정을 지워요.
  Future<void> giveBackOlder(String cid, Member to) async {
    var merged = CourseRecord.empty;
    for (final o in to.older) {
      merged = merged.fillFrom(o.record);
    }
    final pending = await _restore(cid, to.uid).get(const GetOptions(source: Source.server));
    final prev = pending.data()?['record'];
    if (prev is Map) merged = merged.fillFrom(CourseRecord.fromJson(jsonEncode(prev)));
    final batch = _db.batch();
    batch.set(_restore(cid, to.uid), {
      'record': jsonDecode(merged.toJson()),
      'fromName': to.name,
      'at': FieldValue.serverTimestamp(),
    });
    for (final o in to.older) {
      batch.delete(_course(cid).collection('members').doc(o.uid));
      batch.delete(_course(cid).collection('leaders').doc(o.uid));
    }
    await batch.commit();
  }

  /// 관리자: 마지막으로 올린 지 [cutoff]보다 오래된 사본(members)과 돌려주기 상자를 지워요.
  /// 원본은 각자 폰에 있어서 서버 사본만 정리해요. 지운 문서 수를 돌려줘요.
  Future<int> deleteStale(Iterable<String> cids, DateTime cutoff) async {
    final at = Timestamp.fromDate(cutoff);
    var count = 0;
    for (final cid in cids) {
      final members = await _course(cid).collection('members').where('updatedAt', isLessThan: at).get();
      final restores = await _course(cid).collection('restores').where('at', isLessThan: at).get();
      final refs = [
        for (final d in members.docs) ...[d.reference, _course(cid).collection('leaders').doc(d.id)],
        for (final d in restores.docs) d.reference,
      ];
      // batch 하나는 500개까지라 나눠서 지워요
      for (var i = 0; i < refs.length; i += 450) {
        final batch = _db.batch();
        for (final r in refs.skip(i).take(450)) {
          batch.delete(r);
        }
        await batch.commit();
      }
      count += members.size + restores.size;
    }
    return count;
  }

  /// 반장·총무 코드 (관리자만 읽을 수 있어요). 없으면 ''.
  Future<String> readCode(String cid) async {
    final d = await _codes(cid).get();
    final v = d.data()?['code'];
    return v is String ? v : '';
  }

  /// 반장·총무 이름과 코드 저장. 바뀌었으면 지금까지 인정된 반장·총무를 모두 풀어요(새 이름·코드로 다시 넣어야 해요).
  Future<void> saveLeaders(Course c, {required String chief, required String treasurer, required String code}) async {
    final oldCode = await readCode(c.id);
    final changed = oldCode != code || c.chief != chief || c.treasurer != treasurer;
    final batch = _db.batch();
    batch.update(_course(c.id), {
      'leaders': {'chief': chief, 'treasurer': treasurer},
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_codes(c.id), {'code': code});
    if (changed) {
      // 오프라인 캐시 일부만 지우면 권한이 남으니 서버에서 읽어요
      final claims = await _course(c.id).collection('leaders').get(const GetOptions(source: Source.server));
      for (final d in claims.docs) {
        batch.delete(d.reference);
      }
    }
    await batch.commit();
  }
}

/// 이 폰의 익명 로그인 uid (처음이면 익명으로 로그인). 앱을 지우기 전까지 같아요.
/// 웹은 저장된 로그인을 불러오기 전에 currentUser가 비어 있을 수 있어 첫 상태를 기다려요.
/// 예전 버전에서 기본 앱에 구글(관리자)로 로그인해 둔 폰은 로그아웃하고 익명으로 바꿔요(관리자는 이제 따로 로그인).
Future<String> ensureMemberUid(FirebaseAuth auth) async {
  final user = auth.currentUser ?? await auth.authStateChanges().first;
  if (user != null && user.isAnonymous) return user.uid;
  if (user != null) await auth.signOut();
  return (await auth.signInAnonymously()).user!.uid;
}
