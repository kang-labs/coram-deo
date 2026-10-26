import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../core/local_storage.dart';
import '../../course/logic/course_providers.dart';
import '../../record/logic/record_providers.dart';
import '../data/roster_repository.dart';

/// Firebase가 준비됐는지 (위젯 테스트처럼 Firebase 없이 돌 때는 서버 일을 건너뛰어요)
bool get _firebaseReady => Firebase.apps.isNotEmpty;

final rosterRepositoryProvider = Provider<RosterRepository>((ref) => RosterRepository(ref.watch(firestoreProvider)));

/// 관리자 권한으로 읽고 쓰는 저장소 (관리자 전용 Firebase 앱)
final adminRosterRepositoryProvider = Provider<RosterRepository>(
  (ref) => RosterRepository(ref.watch(adminFirestoreProvider)),
);

/// 이 폰의 익명 uid. 처음이면 익명 로그인(구글 계정 필요 없음). 실패하면(오프라인 등) null.
final memberUidProvider = FutureProvider<String?>((ref) async {
  if (!_firebaseReady) return null;
  try {
    return await ensureMemberUid(ref.watch(memberAuthProvider));
  } catch (e) {
    debugPrint('익명 로그인 실패: $e');
    return null;
  }
});

/// 내 기록을 서버에 올려요(반장·총무·관리자가 봐요). 체크가 바뀌면 3초 뒤 한 번만 올리고,
/// 지난번에 올린 내용과 같으면 올리지 않아요(배터리·사용량 아끼기). HomeShell이 watch 해요.
final memberSyncProvider = Provider<void>((ref) {
  final cid = ref.watch(selectedCourseIdProvider);
  final name = ref.watch(myNameProvider);
  final record = ref.watch(courseRecordProvider);
  if (!_firebaseReady || cid == null || name.isEmpty) return;
  final payload = jsonEncode([name, record.toJson()]);
  final prefs = ref.read(sharedPreferencesProvider);
  final sentKey = 'sent.$cid';
  if (prefs.getString(sentKey) == payload) return;
  // await 뒤에는 ref를 쓰지 않게 필요한 것을 먼저 읽어 둬요(그 사이 다시 만들어질 수 있어서)
  final repo = ref.read(rosterRepositoryProvider);
  final uidFuture = ref.read(memberUidProvider.future);
  void retryUidLater() => ref.invalidate(memberUidProvider);
  final timer = Timer(const Duration(seconds: 3), () async {
    try {
      final uid = await uidFuture;
      if (uid == null) {
        // 첫 익명 로그인이 실패했으면(오프라인 등) 다음 체크 때 다시 해요
        retryUidLater();
        return;
      }
      await repo.upload(cid, uid, name, record);
      await prefs.setString(sentKey, payload);
    } catch (e) {
      debugPrint('기록 올리기 실패(다음 체크 때 다시): $e');
    }
  });
  ref.onDispose(timer.cancel);
});

/// 반을 바꿀 때: 떠나는 반 기록이 비어 있으면(잘못 고른 반) 그 반 출석부에서 내 이름을 빼요. 실패해도 괜찮아요.
Future<void> leaveCourseIfEmpty(Ref ref, String cid) async {
  if (!_firebaseReady || !ref.read(localStoreProvider).record(cid).isEmpty) return;
  try {
    final uid = await ref.read(memberUidProvider.future);
    if (uid == null) return;
    await ref.read(rosterRepositoryProvider).removeMine(cid, uid);
    await ref.read(sharedPreferencesProvider).remove('sent.$cid');
  } catch (e) {
    debugPrint('빈 반에서 이름 빼기 실패: $e');
  }
}

/// 관리자가 지금 반 출석부에서 나를 지웠는지. 지웠으면 그 반의 '올림' 표시를 지우고 true.
/// 올린 적이 있는데(sent 있음) 서버 문서가 없으면 지워진 거예요. 처음 올리기 전이거나 확인이 실패하면 false.
Future<bool> checkRemovedByAdmin(WidgetRef ref) async {
  final cid = ref.read(selectedCourseIdProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  if (!_firebaseReady || cid == null || prefs.getString('sent.$cid') == null) return false;
  final repo = ref.read(rosterRepositoryProvider);
  try {
    final uid = await ref.read(memberUidProvider.future);
    if (uid == null || await repo.mineExists(cid, uid)) return false;
    // 그 사이 반을 바꿨거나 처음 올리기가 끝나 상태가 달라졌으면 넘어가요
    if (ref.read(selectedCourseIdProvider) != cid || prefs.getString('sent.$cid') == null) return false;
    await prefs.remove('sent.$cid');
    return true;
  } catch (e) {
    debugPrint('출석부 확인 실패(다음에 다시): $e');
    return false;
  }
}

/// 위 함수를 화면에서 부를 수 있게
final leaveCourseIfEmptyProvider = Provider<Future<void> Function(String cid)>(
  (ref) =>
      (cid) => leaveCourseIfEmpty(ref, cid),
);

/// 지금 반에서 내 이름이 반장·총무로 지정됐는지
final leaderNamedProvider = Provider<bool>((ref) {
  final course = ref.watch(currentCourseProvider).valueOrNull;
  final name = ref.watch(myNameProvider);
  return course != null && course.isLeaderName(name);
});

/// 이 폰이 지금 반의 반장·총무로 인정됐는지 (코드를 넣었는지)
final isLeaderProvider = StreamProvider<bool>((ref) async* {
  final cid = ref.watch(selectedCourseIdProvider);
  if (cid == null || !_firebaseReady || !ref.watch(leaderNamedProvider)) {
    yield false;
    return;
  }
  final uid = await ref.watch(memberUidProvider.future);
  if (uid == null) {
    yield false;
    return;
  }
  yield* ref.watch(rosterRepositoryProvider).watchIsLeader(cid, uid);
});

/// 지정됐는데 아직 코드를 안 넣었는지 (확인이 끝났을 때만 true)
final leaderCodeNeededProvider = Provider<bool>((ref) {
  final leader = ref.watch(isLeaderProvider);
  // 반을 바꾸는 중(loading)에는 이전 반 값이 남아 있으니 기다려요
  return ref.watch(leaderNamedProvider) && !leader.isLoading && leader.hasValue && leader.value == false;
});

/// 반장·총무가 보는 지금 반 사람들 (이름 가나다순, 같은 이름은 최근 것만)
final myClassMembersProvider = StreamProvider<List<Member>>((ref) {
  final cid = ref.watch(selectedCourseIdProvider);
  final leader = ref.watch(isLeaderProvider);
  if (cid == null || leader.isLoading || !(leader.valueOrNull ?? false)) return Stream.value(const []);
  return ref.watch(rosterRepositoryProvider).watchMembers(cid);
});

/// 관리자가 보는 반 사람들
/// 화면을 닫고 2분이 지나면 실시간 구독을 끝내요(사용량·배터리). 그 안에 다시 열면 바로 보여요.
final adminClassMembersProvider = StreamProvider.autoDispose.family<List<Member>, String>((ref, cid) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(const Duration(minutes: 2), link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
  return ref.watch(adminRosterRepositoryProvider).watchMembers(cid);
});

/// 관리자 반 목록이 보일 때 지금 학기 반들의 기록을 한 번씩 미리 받아 둬요.
/// 키는 반 id를 쉼표로 이은 글자라, 목록이 그대로면 다시 그려져도 한 번만 받아요.
final adminPrefetchProvider = FutureProvider.autoDispose.family<void, String>((ref, joinedIds) async {
  if (!_firebaseReady) return;
  final repo = ref.watch(adminRosterRepositoryProvider);
  await Future.wait([
    for (final id in joinedIds.split(','))
      if (id.isNotEmpty) repo.prefetchMembers(id),
  ]);
});
