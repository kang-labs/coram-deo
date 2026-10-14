/// 관리자 이메일 목록. firestore.rules의 isAdmin()에도 같은 목록이 있어요 — 바꾸면 함께 고칩니다.
const adminEmails = ['sdmem7@gmail.com'];

bool isAdminEmail(String? email, {required bool verified}) =>
    verified && email != null && adminEmails.contains(email.toLowerCase());
