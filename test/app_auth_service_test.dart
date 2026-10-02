import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_memory_os/core/services/app_auth_service.dart';
import 'package:personal_memory_os/core/services/auth_service.dart';
import 'package:personal_memory_os/core/services/token_store.dart';

String jwtExpiring(DateTime at) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': at.millisecondsSinceEpoch ~/ 1000})}.sig';
}

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  var now = DateTime(2026, 10, 2, 12);
  late MemoryTokenStore store;
  late List<http.Request> calls;

  AppAuthService make(http.Response Function(http.Request) handler) {
    calls = [];
    return AppAuthService(
      baseUrl: 'http://api',
      tokenStore: store,
      now: () => now,
      httpClient: MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  }

  Map<String, dynamic> loginBody({DateTime? exp}) => {
        'access_token': jwtExpiring(exp ?? now.add(const Duration(hours: 1))),
        'refresh_token': 'refresh-1',
        'user': {'id': 'u1', 'email': 'ada@example.com', 'display_name': 'Ada'},
      };

  setUp(() {
    store = MemoryTokenStore();
    now = DateTime(2026, 10, 2, 12);
  });

  test('sign-in stores the session and returns the user', () async {
    final auth = make((_) => json(loginBody()));
    final user = await auth.signInWithEmail('ada@example.com', 'correct horse');
    expect(user.id, 'u1');
    expect(user.displayName, 'Ada');
    expect(calls.single.url.path, '/auth/login');
    expect(jsonDecode(calls.single.body), {'email': 'ada@example.com', 'password': 'correct horse'});
    expect(await auth.getAccessToken(), isNotNull);
  });

  test('wrong password shows the server message and stores nothing', () async {
    final auth = make((_) => json({'detail': 'Incorrect email or password'}, 401));
    await expectLater(auth.signInWithEmail('a@b.co', 'bad'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Incorrect email or password')));
    expect(await auth.getCurrentUser(), isNull);
  });

  test('lockout message from the server is shown', () async {
    final auth = make((_) => json({'detail': 'Too many failed attempts. Try again later.'}, 429));
    await expectLater(auth.signInWithEmail('a@b.co', 'x'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('Too many'))));
  });

  test('validation errors from FastAPI are readable', () async {
    final auth = make((_) => json({'detail': [{'msg': 'Password must be at least 8 characters'}]}, 422));
    await expectLater(auth.signUp('a@b.co', 'short', 'A'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('at least 8'))));
  });

  test('no connection gives a clear message', () async {
    final auth = make((_) => throw http.ClientException('offline'));
    await expectLater(auth.signInWithEmail('a@b.co', 'x'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('Cannot reach'))));
  });

  test('sign-up registers and signs in at once (no verification step)', () async {
    final auth = make((_) => json(loginBody(), 201));
    final user = await auth.signUp('ada@example.com', 'correct horse', 'Ada');
    expect(calls.single.url.path, '/auth/register');
    expect(user.email, 'ada@example.com');
  });

  test('stays signed in across restarts, even offline', () async {
    await make((_) => json(loginBody())).signInWithEmail('ada@example.com', 'correct horse');
    final restarted = make((_) => throw http.ClientException('offline'));
    expect((await restarted.getCurrentUser())!.email, 'ada@example.com');
  });

  test('a still-valid token is used without a network call', () async {
    final auth = make((_) => json(loginBody()));
    await auth.signInWithEmail('a@b.co', 'x');
    calls.clear();
    await auth.getAccessToken();
    expect(calls, isEmpty);
  });

  test('an expiring token is refreshed quietly', () async {
    var n = 0;
    final auth = make((req) {
      n++;
      if (n == 1) return json(loginBody(exp: now.add(const Duration(seconds: 30))));
      return json({'access_token': jwtExpiring(now.add(const Duration(hours: 1)))});
    });
    await auth.signInWithEmail('a@b.co', 'x');
    final token = await auth.getAccessToken();
    expect(calls.last.url.path, '/auth/refresh');
    expect(jsonDecode(calls.last.body), {'refresh_token': 'refresh-1'});
    expect(AppAuthService.expiryOf(token!)!.isAfter(now), isTrue);
  });

  test('an expired refresh token signs the user out', () async {
    var n = 0;
    final auth = make((_) => ++n == 1
        ? json(loginBody(exp: now.subtract(const Duration(minutes: 5))))
        : json({'detail': 'Session expired. Please sign in again.'}, 401));
    await auth.signInWithEmail('a@b.co', 'x');
    expect(await auth.getAccessToken(), isNull);
    expect(await auth.getCurrentUser(), isNull);
  });

  test('offline during refresh keeps the session', () async {
    var n = 0;
    final auth = make((_) {
      if (++n == 1) return json(loginBody(exp: now.subtract(const Duration(minutes: 5))));
      throw http.ClientException('offline');
    });
    await auth.signInWithEmail('a@b.co', 'x');
    expect(await auth.getAccessToken(), isNotNull);
    expect(await auth.getCurrentUser(), isNotNull);
  });

  test('sign-out clears the session', () async {
    final auth = make((_) => json(loginBody()));
    await auth.signInWithEmail('a@b.co', 'x');
    await auth.signOut();
    expect(await auth.getCurrentUser(), isNull);
  });
}
