import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/admin.dart';

/// 관리자 로그인 (관리자 전용 Firebase 앱). 평소에는 숫자 비밀번호 6자리, 구글 로그인은 비밀번호를 잊었을 때만.
/// 일반 사용자는 로그인하지 않아요.
class AuthRepository {
  AuthRepository(this._auth, this._google);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// GoogleSignIn은 앱에서 한 번만 초기화해야 해서 Future를 저장해 둡니다.
  /// 안드로이드는 google-services.json의 웹 클라이언트 ID를 자동으로 씁니다.
  static Future<void>? _googleReady;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 숫자 비밀번호로 로그인 (관리자 이메일은 앱에 정해져 있어요).
  /// 비밀번호 설정은 PC에서 `python tool/dev/set_admin_pin.py`.
  Future<void> signInWithPin(String pin) => _auth.signInWithEmailAndPassword(email: adminEmails.first, password: pin);

  /// 구글 계정으로 로그인. 사용자가 창을 닫으면 false(오류 아님). 웹은 팝업 창.
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') return false;
        rethrow;
      }
      return true;
    }
    await (_googleReady ??= _google.initialize());
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    await _auth.signInWithCredential(credential);
    return true;
  }

  /// 구글 계정 선택 상태도 지워서, 다음 로그인 때 계정을 다시 고를 수 있게 합니다.
  Future<void> signOut() async {
    if (kIsWeb) return _auth.signOut();
    await (_googleReady ??= _google.initialize());
    await Future.wait([_google.signOut(), _auth.signOut()]);
  }
}
