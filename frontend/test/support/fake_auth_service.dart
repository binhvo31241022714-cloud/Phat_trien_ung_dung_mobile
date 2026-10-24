import 'package:frontend/data/services/auth_service.dart';

/// AuthService giả cho test: không gọi Firebase hay backend, luôn thành công
/// trừ khi đặt [failWith].
class FakeAuthService implements AuthService {
  String? email;
  String? failWith;
  int syncCalls = 0;

  FakeAuthService({this.email});

  @override
  Future<String?> restoreEmail() async => email;

  @override
  Future<void> signIn(String email, String password) async {
    if (failWith != null) throw AuthException(failWith!);
    this.email = email.trim();
  }

  @override
  Future<void> register(String fullName, String email, String password) =>
      signIn(email, password);

  @override
  Future<void> sendPasswordReset(String email) async {
    if (failWith != null) throw AuthException(failWith!);
  }

  @override
  Future<void> signOut() async => email = null;

  @override
  Future<void> syncProfile({String? fullName}) async => syncCalls++;
}
