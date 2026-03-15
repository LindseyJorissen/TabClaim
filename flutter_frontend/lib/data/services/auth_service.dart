import 'package:dio/dio.dart';
import '../models/auth_user.dart';

typedef AuthResult = ({AuthUser user, String access, String refresh});

class AuthService {
  const AuthService(this._dio);
  final Dio _dio;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return _parse(resp.data as Map<String, dynamic>);
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final resp = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
    return _parse(resp.data as Map<String, dynamic>);
  }

  static AuthResult _parse(Map<String, dynamic> data) => (
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
}
