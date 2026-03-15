/// Base URL for the TabClaim API.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000/api
///
/// Defaults:
///   Android emulator  → 10.0.2.2 (maps to host loopback)
///   iOS simulator     → localhost
class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );
}
