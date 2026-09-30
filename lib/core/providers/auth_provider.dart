import 'package:flutter/foundation.dart';
import 'package:personal_memory_os/core/services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
  });
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get error => _error;

  Future<void> checkAuthState() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    try {
      _error = null;
      _user = await _authService.signInWithGoogle();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _error = null;
      _user = await _authService.signInWithEmail(email, password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String displayName) async {
    try {
      _error = null;
      _user = await _authService.signUp(email, password, displayName);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
