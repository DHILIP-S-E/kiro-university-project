import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/config.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/providers/capture_provider.dart';
import 'package:personal_memory_os/core/providers/memory_provider.dart';

// Abstract service interfaces
import 'package:personal_memory_os/core/services/auth_service.dart';
import 'package:personal_memory_os/core/services/ai_service.dart';

// Stub implementations (used when USE_REAL_BACKEND=false)
import 'package:personal_memory_os/core/services/reminder_service.dart';
import 'package:personal_memory_os/core/services/event_service.dart';
import 'package:personal_memory_os/core/services/capture_service.dart';
import 'package:personal_memory_os/core/services/memory_service.dart';

// Real API implementations (used when USE_REAL_BACKEND=true)
import 'package:personal_memory_os/core/services/api_client.dart';
import 'package:personal_memory_os/core/services/api_reminder_service.dart';
import 'package:personal_memory_os/core/services/api_event_service.dart';
import 'package:personal_memory_os/core/services/api_capture_service.dart';
import 'package:personal_memory_os/core/services/api_memory_service.dart';
import 'package:personal_memory_os/core/services/api_ai_service.dart';
import 'package:personal_memory_os/core/services/notification_service.dart';

/// Toggle this to switch between stub data and real FastAPI backend.
/// In production, set via --dart-define=USE_REAL_BACKEND=true
const bool _useRealBackend = bool.fromEnvironment(
  'USE_REAL_BACKEND',
  defaultValue: false, // false = stub mode (no backend needed)
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notification service (device-side alarm layer)
  await NotificationService.initialize(
    onNotificationTap: (payload) {
      // payload = reminder ID; navigate to reminder detail
    },
    onActionTap: (actionId, payload) {
      // 'action_done' / 'action_snooze' — handled in provider
    },
  );

  // In production: await Amplify.configure(amplifyconfig);

  runApp(PersonalMemoryOsApp(useRealBackend: _useRealBackend));
}

class PersonalMemoryOsApp extends StatelessWidget {
  final bool useRealBackend;

  const PersonalMemoryOsApp({super.key, this.useRealBackend = false});

  @override
  Widget build(BuildContext context) {
    // Auth service (always stub until Amplify is configured)
    final authService = StubAuthService();

    // Reminder token getter for API client (returns Cognito JWT in production)
    Future<String?> getToken() async {
      // TODO: return await Amplify.Auth.fetchAuthSession()... .userPoolTokensResult...
      // For now returns null (backend auth middleware accepts this in dev mode)
      return null;
    }

    // Service wiring — swap stubs for real API implementations
    final reminderService = useRealBackend
        ? ApiReminderService(ApiClient(getToken: getToken))
        : StubReminderService() as dynamic;

    final eventService = useRealBackend
        ? ApiEventService(ApiClient(getToken: getToken))
        : StubEventService() as dynamic;

    final captureService = useRealBackend
        ? ApiCaptureService(ApiClient(getToken: getToken))
        : StubCaptureService() as dynamic;

    final memoryService = useRealBackend
        ? ApiMemoryService(ApiClient(getToken: getToken))
        : StubMemoryService() as dynamic;

    final aiService = useRealBackend
        ? ApiAiService(ApiClient(getToken: getToken))
        : StubAiService() as dynamic;

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
