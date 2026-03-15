import 'package:dio/dio.dart';
import '../../core/config/api_config.dart';
import 'secure_token_store.dart';

/// Singleton Dio instance with auth token injection and auto-refresh on 401.
class ApiClient {
  const ApiClient._();

  static final Dio instance = _build();

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_AuthInterceptor());
    return dio;
  }
}

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  /// Separate Dio for refresh calls — bypasses this interceptor to avoid loops.
  final _refreshDio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureTokenStore.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final refreshToken = await SecureTokenStore.getRefreshToken();
    if (refreshToken == null) return handler.next(err);

    try {
      final resp = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final newAccess = resp.data['access'] as String;
      final newRefresh = resp.data['refresh'] as String;
      final user = await SecureTokenStore.getUser();

      if (user != null) {
        await SecureTokenStore.save(
          access: newAccess,
          refresh: newRefresh,
          user: user,
        );
      }

      // Retry original request with fresh token.
      final retried = await ApiClient.instance.fetch(
        err.requestOptions..headers['Authorization'] = 'Bearer $newAccess',
      );
      return handler.resolve(retried);
    } catch (_) {
      await SecureTokenStore.clear();
      return handler.next(err);
    }
  }
}
