/// Backend URL configuration.
/// Override at build time: flutter run --dart-define=BACKEND_URL=https://your-api.com
class AppConfig {
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator → localhost:8000
    // iOS simulator: use 'http://localhost:8000'
    // Physical device on same network: use 'http://192.168.x.x:8000'
    // Production: 'https://api.your-domain.com'
  );
}
