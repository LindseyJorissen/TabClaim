import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_user.dart';

/// Persists auth tokens and user info in platform secure storage.
class SecureTokenStore {
  const SecureTokenStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'tc_access';
  static const _kRefresh = 'tc_refresh';
  static const _kUser = 'tc_user';

  static Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  static Future<AuthUser?> getUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> save({
    required String access,
    required String refresh,
    required AuthUser user,
  }) =>
      Future.wait([
        _storage.write(key: _kAccess, value: access),
        _storage.write(key: _kRefresh, value: refresh),
        _storage.write(key: _kUser, value: jsonEncode(user.toJson())),
      ]);

  static Future<void> clear() => Future.wait([
        _storage.delete(key: _kAccess),
        _storage.delete(key: _kRefresh),
        _storage.delete(key: _kUser),
      ]);
}
