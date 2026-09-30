import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/providers/capture_provider.dart';
import 'package:personal_memory_os/core/providers/memory_provider.dart';
import 'package:personal_memory_os/core/services/auth_service.dart';
import 'package:personal_memory_os/core/services/reminder_service.dart';
import 'package:personal_memory_os/core/services/event_service.dart';
import 'package:personal_memory_os/core/services/capture_service.dart';
import 'package:personal_memory_os/core/services/memory_service.dart';
import 'package:personal_memory_os/core/services/ai_service.dart';
import 'package:personal_memory_os/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notification service (device-side alarm layer)
  await NotificationService.initialize(
    onNotificationTap: (payload) {
      // Navigate to reminder when tapped — handled via GoRouter
    },
    onActionTap: (actionId, payload) {
      // 'action_done' and 'action_snooze' handled here
      // In full implementation: look up provider and call complete/snooze
    },
  );

  // In production: await Amplify.addPlugins([...]) and configure here.
  // await Amplify.configure(amplifyconfig);

  runApp(const PersonalMemoryOsApp());
}

class PersonalMemoryOsApp extends StatelessWidget {
  const PersonalMemoryOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wire up services (swap stubs for real implementations post-backend setup)
    final authService = StubAuthService();
    final reminderService = StubReminderService();
    final eventService = StubEventService();
    final captureService = StubCaptureService();
    final memoryService = StubMemoryService();
    final aiService = StubAiService();

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<AiService>.value(value: aiService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider(
          create: (_) => ReminderProvider(reminderService),
        ),
        ChangeNotifierProvider(
          create: (_) => EventProvider(eventService),
        ),
        ChangeNotifierProvider(
          create: (_) => CaptureProvider(captureService),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoryProvider(memoryService, aiService),
        ),
      ],
      child: MaterialApp.router(
        title: 'Personal Memory OS',
        theme: AppTheme.dark,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
