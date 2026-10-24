import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/api_constants.dart';
import '../api_client.dart';

/// Lỗi đăng nhập/đăng ký, message đã là tiếng Việt để hiện lên UI.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Các thao tác tài khoản. Tách thành interface để test dùng bản giả,
/// không cần Firebase thật.
abstract interface class AuthService {
  /// Email của phiên đăng nhập Firebase còn lưu trên máy, null nếu chưa có.
  Future<String?> restoreEmail();
  Future<void> signIn(String email, String password);
  Future<void> register(String fullName, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Gọi POST /api/users/sync để backend tạo hồ sơ nếu chưa có.
  /// Ném [ApiException] nếu lỗi.
  Future<void> syncProfile({String? fullName});
}

class FirebaseAuthService implements AuthService {
  // Chỉ lấy FirebaseAuth khi thật sự dùng, để tạo đối tượng này không cần
  // Firebase đã khởi tạo.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Future<String?> restoreEmail() async {
    final user = await _auth.authStateChanges().first;
    return user?.email;
  }

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password));

  @override
  Future<void> register(String fullName, String email, String password) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        await cred.user?.updateDisplayName(fullName.trim());
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> syncProfile({String? fullName}) async {
    final name = fullName ?? _auth.currentUser?.displayName;
    await api.post(ApiConstants.usersSync, {
      if (name != null && name.isNotEmpty) 'fullName': name,
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(messageFor(e.code));
    }
  }

  /// Đổi mã lỗi của Firebase sang câu tiếng Việt dễ hiểu.
  static String messageFor(String code) => switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'Email hoặc mật khẩu không đúng.',
        'email-already-in-use' => 'Email này đã được đăng ký.',
        'invalid-email' => 'Email không hợp lệ.',
        'weak-password' => 'Mật khẩu quá yếu, hãy dùng ít nhất 6 ký tự.',
        'user-disabled' => 'Tài khoản này đã bị khóa.',
        'too-many-requests' =>
          'Bạn thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.',
        'network-request-failed' =>
          'Không có kết nối mạng. Vui lòng kiểm tra Internet.',
        'operation-not-allowed' =>
          'Hình thức đăng nhập này chưa được bật. Vui lòng liên hệ hỗ trợ.',
        _ => 'Có lỗi xảy ra, vui lòng thử lại.',
      };
}
