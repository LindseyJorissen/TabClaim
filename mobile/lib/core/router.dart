import 'package:go_router/go_router.dart';
import 'constants/app_routes.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/hangout/claiming_screen.dart';
import '../presentation/screens/hangout/create_hangout_screen.dart';
import '../presentation/screens/receipt/scan_receipt_screen.dart';
import '../presentation/screens/receipt/review_receipt_screen.dart';
import '../presentation/screens/summary/summary_screen.dart';

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
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
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
    GoRoute(
      path: AppRoutes.reviewReceipt, // /hangout/:id/review
      builder: (context, state) {
        final hangoutId = state.pathParameters['id']!;
        final payload = state.extra as ScanPayload?;
        return ReviewReceiptScreen(hangoutId: hangoutId, payload: payload);
      },
    ),
    GoRoute(
      path: AppRoutes.claiming, // /hangout/:id/claim
      builder: (context, state) {
        final hangoutId = state.pathParameters['id']!;
        return ClaimingScreen(hangoutId: hangoutId);
      },
    ),
    GoRoute(
      path: AppRoutes.summary, // /hangout/:id/summary
      builder: (context, state) {
        final args = state.extra as SummaryArgs;
        return SummaryScreen(args: args);
      },
    ),
  ],
);
