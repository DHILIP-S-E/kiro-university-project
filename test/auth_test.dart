import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/core/services/cognito_auth_service.dart';

String _jwt(Map<String, dynamic> claims) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'none'})}.${b64(claims)}.sig';
}

http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/x-amz-json-1.1'});

Map<String, dynamic> _tokens({int expiresIn = 3600, String? refresh = 'r1'}) => {
      'AuthenticationResult': {
        'AccessToken': 'access-1',
        'IdToken': _jwt({'sub': 'user-42', 'email': 'a@b.co', 'name': 'Ada'}),
        if (refresh != null) 'RefreshToken': refresh,
        'ExpiresIn': expiresIn,
      }
    };

void main() {
  late List<http.Request> calls;
  late MemoryTokenStore store;
  var now = DateTime(2026, 10, 1, 12);

  CognitoAuthService make(http.Response Function(http.Request) handler) {
    calls = [];
    return CognitoAuthService(
      region: 'us-east-1',
      clientId: 'client',
      tokenStore: store,
      now: () => now,
      httpClient: MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  }

  String target(http.Request r) => r.headers['X-Amz-Target']!.split('.').last;

  setUp(() {
    store = MemoryTokenStore();
    now = DateTime(2026, 10, 1, 12);
  });

  test('sign-in stores tokens and returns the user from the ID token', () async {
    final auth = make((_) => _json(_tokens()));
    final user = await auth.signInWithEmail('a@b.co', 'pw');
    expect(user.id, 'user-42');
    expect(user.displayName, 'Ada');
    expect(target(calls.single), 'InitiateAuth');
    final body = jsonDecode(calls.single.body);
    expect(body['AuthFlow'], 'USER_PASSWORD_AUTH');
    expect(body['ClientId'], 'client');
    expect(await auth.getAccessToken(), 'access-1');
    expect((await auth.getCurrentUser())!.id, 'user-42');
  });

  test('wrong password gives a friendly error and stores nothing', () async {
    final auth = make((_) => _json(
        {'__type': 'NotAuthorizedException', 'message': 'Incorrect username'},
        400));
    await expectLater(
        auth.signInWithEmail('a@b.co', 'bad'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', 'Incorrect email or password')));
    expect(await auth.getAccessToken(), isNull);
  });

  test('expired access token is refreshed with the refresh token', () async {
    var n = 0;
    final auth = make((req) {
      n++;
      return n == 1
          ? _json(_tokens())
          : _json({
              'AuthenticationResult': {
                'AccessToken': 'access-2',
                'IdToken': _jwt({'sub': 'user-42'}),
                'ExpiresIn': 3600,
              }
            });
    });
    await auth.signInWithEmail('a@b.co', 'pw');
    expect(await auth.getAccessToken(), 'access-1'); // still valid
    now = now.add(const Duration(hours: 2));
    expect(await auth.getAccessToken(), 'access-2');
    final refreshBody = jsonDecode(calls.last.body);
    expect(refreshBody['AuthFlow'], 'REFRESH_TOKEN_AUTH');
    expect(refreshBody['AuthParameters']['REFRESH_TOKEN'], 'r1');
    // The refresh token is kept when Cognito does not rotate it.
    now = now.add(const Duration(hours: 2));
    expect(await auth.getAccessToken(), 'access-2');
    expect(
        jsonDecode(calls.last.body)['AuthParameters']['REFRESH_TOKEN'], 'r1');
  });

  test('revoked refresh token signs the user out', () async {
    var n = 0;
    final auth = make((_) => ++n == 1
        ? _json(_tokens())
        : _json({'__type': 'NotAuthorizedException'}, 400));
    await auth.signInWithEmail('a@b.co', 'pw');
    now = now.add(const Duration(hours: 2));
    expect(await auth.getAccessToken(), isNull);
    expect(await auth.getCurrentUser(), isNull);
  });

  test('sign-up asks for the emailed code; confirm then works', () async {
    final auth = make((_) => _json({'UserConfirmed': false}));
    await expectLater(auth.signUp('a@b.co', 'Passw0rd!', 'Ada'),
        throwsA(isA<ConfirmationRequiredException>()));
    expect(target(calls.single), 'SignUp');
    await auth.confirmSignUp('a@b.co', '123456');
    expect(target(calls.last), 'ConfirmSignUp');
    expect(jsonDecode(calls.last.body)['ConfirmationCode'], '123456');
  });

  test('sign-out clears tokens even when offline', () async {
    var n = 0;
    final auth = make((_) {
      if (++n == 1) return _json(_tokens());
      throw http.ClientException('offline');
    });
    await auth.signInWithEmail('a@b.co', 'pw');
    await auth.signOut();
    expect(await auth.getAccessToken(), isNull);
  });

  test('Google sign-in reports it is not configured (no silent fake login)',
      () {
    final auth = make((_) => _json({}));
    expect(auth.signInWithGoogle(), throwsA(isA<AuthException>()));
  });

  group('auth redirect', () {
    test('unauthenticated users are sent to /auth from anywhere', () {
      for (final loc in ['/today', '/reminders', '/memory/ai-chat', '/events/1']) {
        expect(authRedirect(AuthStatus.unauthenticated, loc), AppRoutes.auth);
      }
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.auth), isNull);
    });

    test('authenticated users never see the login screen', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.auth),
          AppRoutes.today);
      expect(authRedirect(AuthStatus.authenticated, '/reminders'), isNull);
    });

    test('while the session is being restored nothing redirects', () {
      expect(authRedirect(AuthStatus.unknown, '/today'), isNull);
      expect(authRedirect(AuthStatus.unknown, AppRoutes.auth), isNull);
    });
  });
}
