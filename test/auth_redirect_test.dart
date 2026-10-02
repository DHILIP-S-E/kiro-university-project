import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/router/app_router.dart';

void main() {
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
