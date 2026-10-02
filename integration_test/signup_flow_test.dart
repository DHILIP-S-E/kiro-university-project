// Runs the REAL app on a device against the LIVE backend:
//   flutter test integration_test/signup_flow_test.dart -d <device-id>
// Creates a throwaway account, uses the app, then deletes the account.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:personal_memory_os/core/config.dart';
import 'package:personal_memory_os/core/services/app_auth_service.dart';
import 'package:personal_memory_os/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up on the live backend, land on Today, sign out', (tester) async {
    final email = 'device-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'correct horse battery';

    // Start from a clean slate (no stored session).
    await AppAuthService().signOut();

    app.main();
    await tester.pump(const Duration(seconds: 2));

    // Loading screen, then the login screen.
    for (var i = 0; i < 40 && find.text('Welcome back').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Welcome back'), findsOneWidget, reason: 'login screen shows');
    expect(find.textContaining('Google'), findsNothing, reason: 'no Google sign-in');

    // Switch to sign-up.
    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));

    // Wait for the real network round trip, then the Today screen.
    String? shown;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text("TODAY'S BRIEF").evaluate().isNotEmpty) break;
      final snack = find.byType(SnackBar);
      if (snack.evaluate().isNotEmpty) {
        shown = tester.widget<SnackBar>(snack).content.toString();
        break;
      }
    }
    expect(shown, isNull, reason: 'sign-up must not show an error: $shown');
    expect(find.text("TODAY'S BRIEF"), findsOneWidget, reason: 'signed in and on Today');

    // The session is real: the backend knows this user.
    final token = await AppAuthService().getAccessToken();
    expect(token, isNotNull);
    final me = await http.get(Uri.parse('${AppConfig.backendUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $token'});
    expect(me.statusCode, 200);
    expect(jsonDecode(me.body)['email'], email);

    // Clean up the throwaway account.
    final del = await http.delete(Uri.parse('${AppConfig.backendUrl}/account'),
        headers: {'Authorization': 'Bearer $token'});
    expect(del.statusCode, 200);
  });
}
