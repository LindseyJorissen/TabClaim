abstract final class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String createHangout = '/hangout/create';
  static const String hangout = '/hangout/:id';
  static const String scanReceipt = '/hangout/:id/scan';
  static const String reviewReceipt = '/hangout/:id/review';
  static const String claiming = '/hangout/:id/claim';
  static const String summary = '/hangout/:id/summary';
}
