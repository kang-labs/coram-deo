import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 관리자용 Firebase 앱 이름. 관리자 로그인은 이 앱에서만 해요.
/// 기본 앱의 로그인(익명)은 이 폰 사람의 기록을 올리는 '내 자리'라서, 관리자가 로그인·로그아웃해도 바뀌면 안 되기 때문이에요.
const adminAppName = 'admin';

/// 기본 앱: 반 읽기, 내 기록 올리기(익명 로그인)
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final memberAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// 관리자 앱 (main에서 미리 만들어 둬요)
final adminAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instanceFor(app: Firebase.app(adminAppName)));

final adminFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instanceFor(app: Firebase.app(adminAppName)),
);
