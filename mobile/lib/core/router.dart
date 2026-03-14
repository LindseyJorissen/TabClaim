import 'package:go_router/go_router.dart';
import 'constants/app_routes.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/hangout/create_hangout_screen.dart';
import '../presentation/screens/receipt/scan_receipt_screen.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.createHangout,
      builder: (context, state) => const CreateHangoutScreen(),
    ),
    GoRoute(
      path: AppRoutes.scanReceipt, // /hangout/:id/scan
      builder: (context, state) {
        final hangoutId = state.pathParameters['id']!;
        return ScanReceiptScreen(hangoutId: hangoutId);
      },
    ),
    // Review, claiming, summary — added in upcoming parts
  ],
);
