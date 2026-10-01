import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:personal_memory_os/core/config.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/services/auth_service.dart';

/// Thrown after a successful sign-up: Cognito emailed a code the user must enter.
class ConfirmationRequiredException implements Exception {
  final String email;
  const ConfirmationRequiredException(this.email);

  @override
  String toString() => 'Enter the verification code sent to $email';
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Where Cognito tokens live between launches.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> clear() => _storage.deleteAll();
}

class MemoryTokenStore implements TokenStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> clear() async => data.clear();
}

/// Amazon Cognito User Pool auth over Cognito's public JSON API
/// (USER_PASSWORD_AUTH). Tokens are kept in secure storage; the access token is
/// refreshed transparently and is what the FastAPI backend verifies.
class CognitoAuthService implements AuthService {
  final String region;
  final String clientId;
  final http.Client _http;
  final TokenStore _tokens;
  final DateTime Function() _now;

  CognitoAuthService({
    String? region,
    String? clientId,
    http.Client? httpClient,
    TokenStore? tokenStore,
    DateTime Function()? now,
  })  : region = region ?? AppConfig.cognitoRegion,
        clientId = clientId ?? AppConfig.cognitoClientId,
        _http = httpClient ?? http.Client(),
        _tokens = tokenStore ?? SecureTokenStore(),
        _now = now ?? DateTime.now;

  static const _kAccess = 'access_token';
  static const _kId = 'id_token';
  static const _kRefresh = 'refresh_token';
  static const _kExpiry = 'expires_at';

  Uri get _endpoint => Uri.parse('https://cognito-idp.$region.amazonaws.com/');

  Future<Map<String, dynamic>> _call(
      String target, Map<String, dynamic> body) async {
    final response = await _http.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.$target',
      },
      body: jsonEncode({'ClientId': clientId, ...body}),
    );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(_friendly(
          decoded['__type'] as String?, decoded['message'] as String?));
    }
    return decoded;
  }

  static String _friendly(String? type, String? message) {
    switch (type) {
      case 'NotAuthorizedException':
        return 'Incorrect email or password';
      case 'UserNotFoundException':
        return 'No account found for that email';
      case 'UsernameExistsException':
        return 'An account with that email already exists';
      case 'CodeMismatchException':
        return 'That verification code is incorrect';
      case 'ExpiredCodeException':
        return 'That verification code has expired';
      case 'InvalidPasswordException':
        return message ?? 'Password does not meet requirements';
      default:
        return message ?? 'Authentication failed';
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> result,
      {String? keepRefresh}) async {
    await _tokens.write(_kAccess, result['AccessToken'] as String);
    await _tokens.write(_kId, result['IdToken'] as String);
    final refresh = result['RefreshToken'] as String? ?? keepRefresh;
    if (refresh != null) await _tokens.write(_kRefresh, refresh);
    // Refresh a minute early so a token never expires mid-request.
    final expires = _now()
        .add(Duration(seconds: (result['ExpiresIn'] as int? ?? 3600) - 60));
    await _tokens.write(_kExpiry, expires.toIso8601String());
  }

  /// Decode the (Cognito-issued) ID token into the app's user.
  static AppUser userFromIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length != 3) throw const AuthException('Malformed token');
    final claims = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
        as Map<String, dynamic>;
    return AppUser(
      id: claims['sub'] as String,
      email: (claims['email'] as String?) ?? '',
      displayName: claims['name'] as String?,
    );
  }

  /// Access token for the backend, refreshed if expired. Null when signed out.
  Future<String?> getAccessToken() async {
    final access = await _tokens.read(_kAccess);
    if (access == null) return null;
    final expiry = DateTime.tryParse(await _tokens.read(_kExpiry) ?? '');
    if (expiry != null && _now().isBefore(expiry)) return access;
    final refresh = await _tokens.read(_kRefresh);
    if (refresh == null) return null;
    try {
      final res = await _call('InitiateAuth', {
        'AuthFlow': 'REFRESH_TOKEN_AUTH',
        'AuthParameters': {'REFRESH_TOKEN': refresh},
      });
      await _saveTokens(res['AuthenticationResult'] as Map<String, dynamic>,
          keepRefresh: refresh);
      return _tokens.read(_kAccess);
    } on AuthException {
      await _tokens.clear(); // refresh token revoked or expired: signed out
      return null;
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    if (await getAccessToken() == null) return null;
    final id = await _tokens.read(_kId);
    return id == null ? null : userFromIdToken(id);
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final res = await _call('InitiateAuth', {
      'AuthFlow': 'USER_PASSWORD_AUTH',
      'AuthParameters': {'USERNAME': email, 'PASSWORD': password},
    });
    final result = res['AuthenticationResult'] as Map<String, dynamic>?;
    if (result == null) {
      throw AuthException(
          'Additional sign-in step required: ${res['ChallengeName']}');
    }
    await _saveTokens(result);
    return userFromIdToken(result['IdToken'] as String);
  }

  @override
  Future<AppUser> signUp(
      String email, String password, String displayName) async {
    await _call('SignUp', {
      'Username': email,
      'Password': password,
      'UserAttributes': [
        {'Name': 'email', 'Value': email},
        {'Name': 'name', 'Value': displayName},
      ],
    });
    throw ConfirmationRequiredException(email);
  }

  @override
  Future<void> confirmSignUp(String email, String code) =>
      _call('ConfirmSignUp', {'Username': email, 'ConfirmationCode': code});

  @override
  Future<AppUser> signInWithGoogle() async {
    // Needs the Cognito Hosted UI + an OAuth redirect handler (flutter_appauth)
    // with Google configured as an identity provider on the user pool.
    throw const AuthException(
        'Google sign-in is not configured yet. Use email and password.');
  }

  @override
  Future<void> signOut() async {
    final access = await _tokens.read(_kAccess);
    if (access != null) {
      try {
        await _http.post(
          _endpoint,
          headers: {
            'Content-Type': 'application/x-amz-json-1.1',
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.GlobalSignOut',
          },
          body: jsonEncode({'AccessToken': access}),
        );
      } catch (_) {
        // Offline sign-out still clears local tokens.
      }
    }
    await _tokens.clear();
  }
}
