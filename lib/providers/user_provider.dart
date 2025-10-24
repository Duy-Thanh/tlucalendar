import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/models/user.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  late User _currentUser;
  late SharedPreferences _prefs;
  late AuthService _authService;
  bool _isLoggedIn = false;
  String? _accessToken;

  static const String _studentCodeKey = 'userStudentCode';
  static const String _passwordKey = 'userPassword';
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _isLoggedInKey = 'isLoggedIn';

  User get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get accessToken => _accessToken;

  UserProvider() {
    // Initialize with sample user
    _currentUser = User(
      studentId: '2251061884',
      fullName: 'Nekkochan',
      email: 'nekkochan@tlu.edu.vn',
    );
    _authService = AuthService();
  }

  /// Initialize SharedPreferences and load saved login credentials
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isLoggedIn = _prefs.getBool(_isLoggedInKey) ?? false;
    _accessToken = _prefs.getString(_accessTokenKey);

    if (_isLoggedIn && _accessToken != null) {
      // Try to load user from saved token
      try {
        final isValid = await _authService.isTokenValid(_accessToken!);
        if (isValid) {
          final tluUser = await _authService.getCurrentUser(_accessToken!);
          _updateUserFromTluUser(tluUser);
        } else {
          // Token expired, need to re-login
          _isLoggedIn = false;
        }
      } catch (e) {
        // Error fetching user, reset login state
        _isLoggedIn = false;
      }
    }
    notifyListeners();
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Update user from TLU API response
  void _updateUserFromTluUser(TluUser tluUser) {
    _currentUser = User(
      studentId: tluUser.username,
      fullName: tluUser.displayName,
      email: tluUser.email,
    );
  }

  /// Login with real TLU API
  Future<void> loginWithApi(String studentCode, String password) async {
    try {
      // Step 1: Get access token
      final loginResponse = await _authService.login(studentCode, password);
      _accessToken = loginResponse.accessToken;

      // Step 2: Fetch user data
      final tluUser = await _authService.getCurrentUser(_accessToken!);

      // Step 3: Update user and save credentials
      _updateUserFromTluUser(tluUser);
      _isLoggedIn = true;

      // Save to device
      await _prefs.setString(_studentCodeKey, studentCode);
      await _prefs.setString(_passwordKey, password);
      await _prefs.setString(_accessTokenKey, loginResponse.accessToken);
      await _prefs.setString(_refreshTokenKey, loginResponse.refreshToken);
      await _prefs.setBool(_isLoggedInKey, true);

      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      _accessToken = null;
      rethrow;
    }
  }

  /// Log out and clear saved credentials
  Future<void> logout() async {
    await _prefs.remove(_studentCodeKey);
    await _prefs.remove(_passwordKey);
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.setBool(_isLoggedInKey, false);
    _isLoggedIn = false;
    _accessToken = null;

    // Reset to sample user
    _currentUser = User(
      studentId: '2251061884',
      fullName: 'Nekkochan',
      email: 'nekkochan@tlu.edu.vn',
    );
    notifyListeners();
  }


  /// Get saved student code (if exists)
  String? getSavedStudentCode() {
    return _prefs.getString(_studentCodeKey);
  }

  /// Get saved password (if exists)
  String? getSavedPassword() {
    return _prefs.getString(_passwordKey);
  }
}