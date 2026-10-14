import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/admin.dart';
import '../../../core/firebase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), GoogleSignIn.instance),
);

/// 로그인 상태 (관리자 모드에서만 씀). null이면 로그아웃.
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());

/// 로그인한 사람이 관리자인지 (이메일 확인된 관리자 이메일)
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return isAdminEmail(user?.email, verified: user?.emailVerified ?? false);
});
