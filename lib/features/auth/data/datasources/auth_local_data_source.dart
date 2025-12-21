import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/core/error/failures.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> clearCache();

  Future<void> saveCredentials(String studentCode, String password);
  Future<Map<String, String>> getCredentials();
  Future<void> clearCredentials();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;
  // Note: For production, use FlutterSecureStorage for credentials.
  // keeping simple for refactor step 1, or use secure storage if available.

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  static const String _accessTokenKey = 'accessToken';
  static const String _studentCodeKey = 'userStudentCode';
  static const String _passwordKey = 'userPassword';

  @override
  Future<void> cacheAccessToken(String token) async {
    await sharedPreferences.setString(_accessTokenKey, token);
  }

  @override
  Future<String?> getAccessToken() async {
    return sharedPreferences.getString(_accessTokenKey);
  }

  @override
  Future<void> clearCache() async {
    await sharedPreferences.remove(_accessTokenKey);
  }

  @override
  Future<void> saveCredentials(String studentCode, String password) async {
    // In real app, use FlutterSecureStorage
    await sharedPreferences.setString(_studentCodeKey, studentCode);
    await sharedPreferences.setString(_passwordKey, password);
  }

  @override
  Future<Map<String, String>> getCredentials() async {
    final code = sharedPreferences.getString(_studentCodeKey);
    final pass = sharedPreferences.getString(_passwordKey);
    if (code != null && pass != null) {
      return {'username': code, 'password': pass};
    } else {
      throw const CacheFailure('No credentials found');
    }
  }

  @override
  Future<void> clearCredentials() async {
    await sharedPreferences.remove(_studentCodeKey);
    await sharedPreferences.remove(_passwordKey);
  }
}
