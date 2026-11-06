import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/device_kind.dart';
import '../../../core/models/course.dart';
import '../../record/data/course_record.dart';

/// 반 사람 한 명의 출석부 (서버 `courses/{반}/members/{익명 uid}`)
@immutable
class Member {
  const Member({
    required this.uid,
    required this.name,
    required this.record,
    this.updatedAt,
    this.device,
    this.older = const [],
  });

  final String uid;
  final String name;
  final CourseRecord record;
  final DateTime? updatedAt;

  /// 올린 기기 종류 (시험 운영 기간에만 올려요, [collectDeviceKind]). 예전 앱이 올렸으면 null.
  final DeviceKind? device;

  /// 같은 이름으로 남은 예전 문서들 (최근 것 먼저). 앱을 다시 깔았거나 동명이인일 때 생겨요.
  final List<Member> older;

  Member withOlder(List<Member> older) =>
      Member(uid: uid, name: name, record: record, updatedAt: updatedAt, device: device, older: older);

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
      device: DeviceKind.fromCode(m['device']),
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

/// 관리자 '사용자 관리' 한 줄: 어느 반의 누구인지.
/// [phoneCid]는 옮기기 상자가 있는 반 = 그 폰이 아직 고른 채로 있는 반(앱을 열면 새 반으로 바뀌어요). 없으면 null.
typedef UserEntry = ({Course course, Member member, String? phoneCid});

/// 사용자 관리 목록 순서: 이름 가나다순, 같은 이름이면 반 순서
List<UserEntry> sortUsers(Iterable<UserEntry> users) => users.toList()
  ..sort((a, b) {
    final n = a.member.name.compareTo(b.member.name);
    return n != 0 ? n : a.course.order.compareTo(b.course.order);
  });

/// 이름 검색 (띄어쓰기·대소문자 무시, 일부만 맞아도). 빈 검색이면 전부.
bool nameMatches(String name, String query) {
  final q = normalizeName(query);
  return q.isEmpty || normalizeName(name).contains(q);
}

/// [target]에게 기록을 가져와 줄 수 있는 같은 반 문서들. 같은 이름(예전 기록)을 먼저, 나머지는 이름순.
/// [courseMembers]는 그 반 출석부(같은 이름은 [Member.older]에 담긴 것)예요. 기록이 빈 문서는 빼요.
({List<Member> sameName, List<Member> others}) importCandidates(List<Member> courseMembers, Member target) {
  final key = normalizeName(target.name);
  final docs = [
    for (final m in courseMembers) ...[m, ...m.older],
  ].where((d) => d.uid != target.uid && !d.record.isEmpty);
  final same = [
    for (final d in docs)
      if (normalizeName(d.name) == key) d,
  ];
  final others = [
    for (final d in docs)
      if (normalizeName(d.name) != key) d,
  ]..sort((a, b) => a.name.compareTo(b.name));
  return (sameName: same, others: others);
}

/// 출석부 순서: 반장 → 총무 → 나머지 이름 가나다순. 반장·총무 줄 이름 아래에 보일 역할 글도 같이.
List<({Member member, String? role})> rosterOrder(List<Member> members, Course course) {
  int rank(String? role) => switch (role) {
    '반장' => 0,
    '총무' => 1,
    _ => 2,
  };
  final rows = [for (final m in members) (member: m, role: course.leaderRole(m.uid, m.name))];
  rows.sort((a, b) {
    final r = rank(a.role).compareTo(rank(b.role));
    return r != 0 ? r : a.member.name.compareTo(b.member.name);
  });
  return rows;
}

/// 반 사람 기록 올리기·보기, 반장·총무 지정
class RosterRepository {
  RosterRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _course(String cid) => _db.collection('courses').doc(cid);

  /// 내 기록 올리기 (익명 uid 자리). 기록이 비어도 이름은 올려서 반장 출석부에 보이게 해요.
  /// [device]가 있으면 기기 종류도 같이 올려요(시험 운영 기간에만).
  Future<void> upload(String cid, String uid, String name, CourseRecord record, {DeviceKind? device}) => _course(cid)
      .collection('members')
      .doc(uid)
      .set({
        'name': name,
        'record': jsonDecode(record.toJson()),
        'device': ?device?.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

  DocumentReference<Map<String, dynamic>> _move(String cid, String uid) => _course(cid).collection('moves').doc(uid);

  /// 상자 문서의 기록 (없거나 모양이 다르면 빈 기록)
  static CourseRecord _boxRecord(DocumentSnapshot<Map<String, dynamic>> d) {
    final r = d.data()?['record'];
    return r is Map ? CourseRecord.fromJson(jsonEncode(r)) : CourseRecord.empty;
  }

  /// 관리자가 남긴 반 옮기기 (없으면 null): 옮길 반 id와 같이 들고 갈 예전 기록. 서버에서만 읽어요(실패하면 예외).
  Future<({String to, CourseRecord record})?> readMove(String cid, String uid) async {
    final d = await _move(cid, uid).get(const GetOptions(source: Source.server));
    final to = d.data()?['to'];
    return d.exists && to is String && to.isNotEmpty ? (to: to, record: _boxRecord(d)) : null;
  }

  /// 새 반으로 옮긴 뒤: 옛 반의 옮기기 상자·내 출석부·반장 인정을 한 번에 지워요.
  Future<void> finishMove(String cid, String uid) =>
      (_db.batch()
            ..delete(_move(cid, uid))
            ..delete(_course(cid).collection('members').doc(uid))
            ..delete(_course(cid).collection('leaders').doc(uid)))
          .commit();

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

  // ── 관리자 ──

  /// 출석부에서 사람 지우기. 이 이름(띄어쓰기·대소문자 무시)으로 올라온 문서를 모두 지워요.
  /// 앱을 다시 깔아 생긴 옛 문서도 같이 지워야 옛 기록이 대신 나타나지 않아요. 반장·총무 인정도 같이 풀어요.
  /// 오프라인 캐시에 없는 문서를 놓치지 않게 서버에서 읽어요. 지운 문서 수를 돌려줘요.
  Future<int> removeMembersNamed(String cid, String name) async {
    final key = normalizeName(name);
    final docs = await _course(cid).collection('members').get(const GetOptions(source: Source.server));
    final batch = _db.batch();
    final gone = <String>{};
    for (final d in docs.docs) {
      final v = d.data()['name'];
      if (v is! String || normalizeName(v) != key) continue;
      batch.delete(d.reference);
      batch.delete(_course(cid).collection('leaders').doc(d.id));
      gone.add(d.id);
    }
    if (gone.isEmpty) return 0;
    await _passLeaders(batch, cid, gone);
    await batch.commit();
    return gone.length;
  }

  /// 관리자: 반 사람 전부를 한 번 읽어요(사용자 관리). 같은 이름은 [Member.older]에.
  Future<List<Member>> fetchMembers(String cid) async {
    final s = await _course(cid).collection('members').get();
    return latestByName([for (final d in s.docs) ?Member.fromDoc(d.id, d.data())]);
  }

  /// 관리자: [from] 문서들의 기록을 같은 반 [to]의 폰에 가져와 줘요. 그 폰이 다음에 앱을 열면 빈 칸만 채워요.
  /// [from] 순서대로(앞이 먼저) 합치고, 아직 안 가져간 상자가 있으면 그것도 합쳐요.
  /// 한 번에(batch) 상자를 채우고, [from] 문서와 그 반장·총무 인정을 출석부에서 지워요(같은 사람이 두 줄로 나오지 않게).
  Future<void> giveBack(String cid, Member to, List<Member> from) async {
    assert(from.every((o) => o.uid != to.uid));
    var merged = CourseRecord.empty;
    for (final o in from) {
      merged = merged.fillFrom(o.record);
    }
    merged = merged.fillFrom(_boxRecord(await _restore(cid, to.uid).get(const GetOptions(source: Source.server))));
    final batch = _db.batch();
    batch.set(_restore(cid, to.uid), {
      'record': jsonDecode(merged.toJson()),
      'fromName': {for (final o in from) o.name}.join(', '),
      'at': FieldValue.serverTimestamp(),
    });
    for (final o in from) {
      batch.delete(_course(cid).collection('members').doc(o.uid));
      batch.delete(_course(cid).collection('leaders').doc(o.uid));
    }
    // 앱을 다시 깐 반장·총무면 역할을 새 폰([to])으로 넘겨요
    await _passLeaders(batch, cid, {for (final o in from) o.uid}, to: to);
    await batch.commit();
  }

  /// 관리자: 이 반에 남은 옮기기 상자들 (익명 uid → 옮길 반 id). 폰이 아직 앱을 안 연 사람들이에요.
  /// 못 읽으면(서버 규칙을 아직 안 올렸을 때 등) 빈 목록 — 사용자 목록은 그대로 보이게.
  Future<Map<String, String>> fetchMoves(String cid) async {
    final QuerySnapshot<Map<String, dynamic>> s;
    try {
      s = await _course(cid).collection('moves').get();
    } catch (e) {
      debugPrint('옮기는 중 목록을 못 읽었어요: $e');
      return const {};
    }
    return {
      for (final d in s.docs)
        if (d.data()['to'] case final String to when to.isNotEmpty) d.id: to,
    };
  }

  /// 관리자: [m]을 [from] 반에서 [to] 반으로 바로 옮겨요.
  /// 서버 출석부는 지금 바꿔요: [to] 반에 사본(그 반에 있는 칸 기록만)을 만들고, [from] 반의 이 사람 문서·반장 인정과
  /// 같은 이름 예전 문서(앱을 다시 깐 사람)를 지워요. 예전 문서 기록은 사본과 옮기기 상자에 합쳐요.
  /// 반 선택은 그 폰에만 있어서, 폰이 있는 반([phoneCid], 없으면 [from])에 옮기기 상자를 남겨요.
  /// 폰은 다음에 앱을 열면 [to] 반으로 바뀌고 자기 기록을 들고 가요([takeMove]).
  /// 폰이 있는 반으로 되돌리면 상자를 지우고, 상자의 예전 기록은 그 반 돌려주기 상자로 보내 잃지 않아요.
  Future<void> moveMember(Course from, Member m, Course to, {String? phoneCid}) async {
    assert(from.id != to.id);
    final home = phoneCid ?? from.id;
    var carried = _boxRecord(await _move(home, m.uid).get(const GetOptions(source: Source.server)));
    for (final o in m.older) {
      carried = carried.fillFrom(o.record);
    }
    final batch = _db.batch();
    if (to.id == home) {
      batch.delete(_move(home, m.uid));
      if (!carried.isEmpty) {
        final pending = await _restore(home, m.uid).get(const GetOptions(source: Source.server));
        batch.set(_restore(home, m.uid), {
          'record': jsonDecode(_boxRecord(pending).fillFrom(carried).toJson()),
          'fromName': m.name,
          'at': FieldValue.serverTimestamp(),
        });
      }
    } else {
      batch.set(_move(home, m.uid), {
        'to': to.id,
        'record': jsonDecode(carried.toJson()),
        'at': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_course(to.id).collection('members').doc(m.uid), {
      'name': m.name,
      'record': jsonDecode(m.record.fillFrom(carried).onlyFor(to).toJson()),
      'device': ?m.device?.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final d in [m, ...m.older]) {
      batch
        ..delete(_course(from.id).collection('members').doc(d.uid))
        ..delete(_course(from.id).collection('leaders').doc(d.uid));
    }
    await _passLeaders(batch, from.id, {
      for (final d in [m, ...m.older]) d.uid,
    });
    await batch.commit();
  }

  /// 관리자: 마지막으로 올린 지 [cutoff]보다 오래된 사본(members)과 돌려주기·옮기기 상자를 지워요.
  /// 원본은 각자 폰에 있어서 서버 사본만 정리해요. 지운 문서 수를 돌려줘요.
  Future<int> deleteStale(Iterable<String> cids, DateTime cutoff) async {
    final at = Timestamp.fromDate(cutoff);
    var count = 0;
    for (final cid in cids) {
      final members = await _course(cid).collection('members').where('updatedAt', isLessThan: at).get();
      final restores = await _course(cid).collection('restores').where('at', isLessThan: at).get();
      final moves = await _course(cid).collection('moves').where('at', isLessThan: at).get();
      final refs = [
        for (final d in members.docs) ...[d.reference, _course(cid).collection('leaders').doc(d.id)],
        for (final d in restores.docs) d.reference,
        for (final d in moves.docs) d.reference,
      ];
      // batch 하나는 500개까지라 나눠서 지워요
      for (var i = 0; i < refs.length; i += 450) {
        final batch = _db.batch();
        for (final r in refs.skip(i).take(450)) {
          batch.delete(r);
        }
        await batch.commit();
      }
      count += members.size + restores.size + moves.size;
    }
    return count;
  }

  /// 인정 문서 하나 (`leaders/{uid}`, role = chief·treasurer·staff)
  void _grant(WriteBatch batch, String cid, String uid, String name, String role) => batch.set(
    _course(cid).collection('leaders').doc(uid),
    {'name': normalizeName(name), 'role': role, 'at': FieldValue.serverTimestamp()},
  );

  /// 반 문서 `leaders` 값
  static Map<String, Object> _leadersMap(StaffRef? chief, StaffRef? treasurer, List<StaffRef> staff) => {
    'chief': chief?.name ?? '',
    'treasurer': treasurer?.name ?? '',
    'chiefUid': chief?.uid ?? '',
    'treasurerUid': treasurer?.uid ?? '',
    'staff': [for (final s in staff) s.toMap()],
  };

  /// 출석부에서 빠지는 폰들([gone]) 중에 반장·총무·양육국으로 고른 사람이 있으면, 반 문서의 그 역할을 [to]에게 넘기거나
  /// ([to]가 없으면) 비워요. 표시(반 목록·출석부 역할 글)와 권한이 어긋나지 않게 [batch]에 같이 넣어요.
  /// 이름+코드로 정하던 예전 반(uid 없음)은 그대로 둬요(그 반은 관리자가 다시 고르면 바뀌어요).
  Future<void> _passLeaders(WriteBatch batch, String cid, Set<String> gone, {Member? to}) async {
    final doc = await _course(cid).get(const GetOptions(source: Source.server));
    final data = doc.data();
    if (data == null) return;
    final c = Course.fromMap(cid, data);
    final next = to == null ? null : StaffRef(uid: to.uid, name: to.name);
    StaffRef? pass(String uid, String name) =>
        uid.isEmpty ? null : (gone.contains(uid) ? next : StaffRef(uid: uid, name: name));
    final chief = pass(c.chiefUid, c.chief), treasurer = pass(c.treasurerUid, c.treasurer);
    final staff = <StaffRef>[
      for (final s in c.staff)
        if (pass(s.uid, s.name) case final r? when r.uid != chief?.uid && r.uid != treasurer?.uid) r,
    ];
    // 같은 사람이 두 번 들어가지 않게 (옛 폰 둘을 한 폰으로 합칠 때)
    final seen = <String>{};
    staff.retainWhere((s) => seen.add(s.uid));
    final changed =
        chief != (c.chiefUid.isEmpty ? null : StaffRef(uid: c.chiefUid, name: c.chief)) ||
        treasurer != (c.treasurerUid.isEmpty ? null : StaffRef(uid: c.treasurerUid, name: c.treasurer)) ||
        !listEquals(staff, c.staff);
    if (!changed) return;
    batch.update(_course(cid), {
      'leaders': _leadersMap(chief, treasurer, staff),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (next != null) {
      final role = chief == next ? 'chief' : (treasurer == next ? 'treasurer' : 'staff');
      if (role != 'staff' || staff.contains(next)) _grant(batch, cid, next.uid, next.name, role);
    }
  }

  /// 반장·총무·양육국 정하기: 출석부에서 고른 사람([chief]·[treasurer]는 없으면 null, [staff]는 여럿)에게
  /// 권한(`leaders/{uid}`)을 주고, 그 밖의 인정은 모두 풀어요. 같은 사람을 다시 고르면(예전에 코드로 인정된 사람 포함) 권한이 그대로 이어져요.
  Future<void> saveLeaders(Course c, {Member? chief, Member? treasurer, List<Member> staff = const []}) async {
    assert(staff.every((m) => m.uid != chief?.uid && m.uid != treasurer?.uid));
    // 오프라인 캐시 일부만 지우면 권한이 남으니 서버에서 읽어요
    final claims = await _course(c.id).collection('leaders').get(const GetOptions(source: Source.server));
    final keep = {?chief?.uid, ?treasurer?.uid, for (final m in staff) m.uid};
    StaffRef? ref(Member? m) => m == null ? null : StaffRef(uid: m.uid, name: m.name);
    final batch = _db.batch();
    batch.update(_course(c.id), {
      'leaders': _leadersMap(ref(chief), ref(treasurer), [for (final m in staff) ref(m)!]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final d in claims.docs) {
      if (!keep.contains(d.id)) batch.delete(d.reference);
    }
    for (final (m, role) in [(chief, 'chief'), (treasurer, 'treasurer'), for (final m in staff) (m, 'staff')]) {
      if (m != null) _grant(batch, c.id, m.uid, m.name, role);
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
