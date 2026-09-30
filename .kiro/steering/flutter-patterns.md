---
inclusion: fileMatch
fileMatchPattern: "lib/**/*.dart"
---

# Flutter Patterns & Conventions

## Project Structure

```
lib/
  main.dart                       ← app entry, provider wiring
  shell.dart                      ← NavigationBar shell (ShellRoute)
  core/
    models/                       ← pure data classes (no Flutter deps)
    services/                     ← abstract service + stub implementation
    providers/                    ← ChangeNotifier providers
    router/                       ← go_router config
    theme/                        ← AppColors, AppTextStyles, AppTheme
    utils/                        ← date_utils, etc.
  features/
    today/                        ← Today/Home screen
    reminders/screens|widgets/
    capture/screens|widgets/
    memory/screens|widgets/
    events/screens|widgets/
    settings/
    auth/
  shared/widgets/                 ← cross-feature reusable widgets
  aws/                            ← Amplify config
```

## State Management Pattern

```dart
// 1. Abstract service interface
abstract class FooService {
  Future<List<Foo>> fetchFoos();
}

// 2. Stub for dev/test
class StubFooService implements FooService { ... }

// 3. Provider wraps service
class FooProvider extends ChangeNotifier {
  final FooService _service;
  FooProvider(this._service);
}

// 4. Wire in main.dart
ChangeNotifierProvider(create: (_) => FooProvider(StubFooService()))

// 5. Consume in widget
Consumer<FooProvider>(builder: (ctx, p, _) => ...)
// or
context.watch<FooProvider>()
```

## Navigation

- Use `go_router` with named route constants in `AppRoutes`
- Shell screens (main nav) use `context.go()`
- Full-screen flows use `context.push()` / `context.pop()`
- Never use `Navigator.push` directly

## Theming Rules

- Background color: always `AppColors.background` on `Scaffold`
- Cards: `AppColors.surface` with `AppColors.cardBorder` border
- Elevated cards: `AppColors.surfaceElevated`
- Text: `AppTextStyles.*` constants — never inline `TextStyle(fontSize: ...)`
- Colors: `AppColors.*` — never inline hex values

## AI Suggestion Pattern

Any time the app shows an AI-generated suggestion that would create or modify
a record, it MUST use `AiSuggestionBanner` and require user confirmation:

```dart
AiSuggestionBanner(
  message: 'AI found a deadline: October 20',
  confirmLabel: 'Create Reminder',
  dismissLabel: 'Ignore',
  onConfirm: _createReminder,
  onDismiss: _dismiss,
)
```

Never silently create reminders, events, or action items from AI output.

## Error Handling

- Show errors as `SnackBar` with `AppColors.urgent` background
- Never swallow exceptions silently in providers
- Use `rethrow` after setting `_error` so callers can react

## Offline / Sync

- Local records start with `syncStatus: 'LOCAL_ONLY'`
- After successful API call, update to `syncStatus: 'SYNCED'`
- Queue captures locally and upload when connectivity returns
- Cloud is the source of truth after sync

## Accessibility

- All `GestureDetector` taps that behave as buttons should be wrapped in
  `Semantics` or use actual `*Button` widgets
- Icon-only buttons must include `tooltip`
- Minimum touch target: 48×48 logical pixels
