/// 관리자 이메일 목록. firestore.rules의 isAdmin()에도 같은 목록이 있어요 — 바꾸면 함께 고칩니다.
/// 첫 번째는 숫자 비밀번호 로그인 계정이라 순서를 바꾸지 않아요. 나머지는 구글 로그인으로 들어와요.
const adminEmails = ['bible4217@gmail.com', 'kanglabscontact@gmail.com'];

bool isAdminEmail(String? email, {required bool verified}) =>
    verified && email != null && adminEmails.contains(email.toLowerCase());
