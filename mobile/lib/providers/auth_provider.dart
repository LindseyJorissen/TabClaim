import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/api_config.dart';
import '../data/models/auth_user.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_service.dart';
import '../data/services/secure_token_store.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({this.user, this.isGuest = false});

  final AuthUser? user;
  final bool isGuest;

  bool get isAuthenticated => user != null;

  /// True when there is a usable session (signed-in or explicitly guest).
  bool get hasSession => isAuthenticated || isGuest;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  late final AuthService _service;
  static const _kGuest = 'tc_is_guest';

  @override
  Future<AuthState> build() async {
    _service = AuthService(ApiClient.instance);
    return _restoreSession();
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Throws on failure so callers can display inline errors.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final result = await _service.login(email: email, password: password);
    await SecureTokenStore.save(
      access: result.access,
      refresh: result.refresh,
      user: result.user,
    );
    await _clearGuest();
    state = AsyncData(AuthState(user: result.user));
  }

  /// Throws on failure so callers can display inline errors.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final result = await _service.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    await SecureTokenStore.save(
      access: result.access,
      refresh: result.refresh,
      user: result.user,
    );
    await _clearGuest();
    state = AsyncData(AuthState(user: result.user));
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuest, true);
    state = const AsyncData(AuthState(isGuest: true));
  }

  Future<void> logout() async {
    await SecureTokenStore.clear();
    await _clearGuest();
    state = const AsyncData(AuthState());
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  Future<AuthState> _restoreSession() async {
    // Check guest flag first (no network needed).
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool(_kGuest) ?? false;

    final user = await SecureTokenStore.getUser();
    final refreshToken = await SecureTokenStore.getRefreshToken();

    if (user == null || refreshToken == null) {
      return AuthState(isGuest: isGuest);
    }

    // Silently refresh tokens in the background.
    try {
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final resp = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      await SecureTokenStore.save(
        access: resp.data['access'] as String,
        refresh: resp.data['refresh'] as String,
        user: user,
      );
      return AuthState(user: user);
    } catch (_) {
      // Refresh token expired — clear and fall through to guest/unauthenticated.
      await SecureTokenStore.clear();
      return AuthState(isGuest: isGuest);
    }
  }

  Future<void> _clearGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGuest);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
