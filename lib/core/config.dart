/// Backend URL configuration.
/// Override at build time: flutter run --dart-define=BACKEND_URL=https://your-api.com
class AppConfig {
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    // The live backend (AWS App Runner). To use a local server instead:
    //   Android emulator:  --dart-define=BACKEND_URL=http://10.0.2.2:8000
    //   iOS simulator:     --dart-define=BACKEND_URL=http://localhost:8000
    //   Phone on same Wi-Fi: --dart-define=BACKEND_URL=http://192.168.x.x:8000
    defaultValue: 'https://wrducpxx4p.ap-south-1.awsapprunner.com',
  );
}
