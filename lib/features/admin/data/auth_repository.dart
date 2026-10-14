import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 관리자 모드 구글 로그인 (성경가계부와 같은 방식). 일반 사용자는 로그인하지 않아요.
class AuthRepository {
  AuthRepository(this._auth, this._google);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// GoogleSignIn은 앱에서 한 번만 초기화해야 해서 Future를 저장해 둡니다.
  /// 안드로이드는 google-services.json의 웹 클라이언트 ID를 자동으로 씁니다.
  static Future<void>? _googleReady;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 구글 계정으로 로그인. 폰의 계정 선택 창을 씁니다. 사용자가 창을 닫으면 false(오류 아님).
  Future<bool> signInWithGoogle() async {
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
    await (_googleReady ??= _google.initialize());
    await Future.wait([_google.signOut(), _auth.signOut()]);
  }
}
