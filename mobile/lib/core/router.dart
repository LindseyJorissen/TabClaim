import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'constants/app_routes.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/hangout/create_hangout_screen.dart';

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
    // Scan, review, claiming, summary — added as stages are built
  ],
);
