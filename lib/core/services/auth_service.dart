import 'package:personal_memory_os/core/providers/auth_provider.dart';

/// Abstracts Amazon Cognito authentication via AWS Amplify.
/// Swap the stub implementations with real Amplify calls once the backend is provisioned.
abstract class AuthService {
  Future<AppUser?> getCurrentUser();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signUp(String email, String password, String displayName);
  Future<void> signOut();
}

/// Stub implementation — returns mock data in development.
/// Replace with AmplifyAuthService using amplify_auth_cognito package.
class StubAuthService implements AuthService {
  AppUser? _currentUser;

  @override
  Future<AppUser?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _currentUser;
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = AppUser(
      id: 'user_${email.hashCode.abs()}',
      email: email,
      displayName: email.split('@').first,
    );
    return _currentUser!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = const AppUser(
      id: 'google_user_001',
      email: 'user@example.com',
      displayName: 'Demo User',
    );
    return _currentUser!;
  }

  @override
  Future<AppUser> signUp(
      String email, String password, String displayName) async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = AppUser(
      id: 'user_${email.hashCode.abs()}',
      email: email,
      displayName: displayName,
    );
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
  }
}
