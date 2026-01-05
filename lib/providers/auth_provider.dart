import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tlucalendar/features/auth/data/models/user_model.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/auth/domain/usecases/login_usecase.dart';
import 'package:tlucalendar/features/auth/domain/usecases/get_user_usecase.dart';

class AuthProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final GetUserUseCase getUserUseCase;

  AuthProvider({required this.loginUseCase, required this.getUserUseCase});

  // State
  UserModel? _currentUser;

  late SharedPreferences _prefs;
  final _storage = const FlutterSecureStorage();
  final _log = LogService();
  bool _isLoggedIn = false;
  String? _accessToken;
  Map<String, dynamic>? _rawTokenData;
  String? _rawTokenStr;

  // Login progress tracking
  String _loginProgress = '';
  double _loginProgressPercent = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  static const String _accessTokenKey = 'accessToken';

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get rawTokenData => _rawTokenData;
  String? get rawTokenStr => _rawTokenStr;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Login progress getters
  String get loginProgress => _loginProgress;
  double get loginProgressPercent => _loginProgressPercent;

  /// Initialize provider
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Check if logged in
    final accessToken = _prefs.getString(_accessTokenKey);
    final rawTokenJson = _prefs.getString('rawToken');

    if (accessToken != null) {
      _accessToken = accessToken;
      if (rawTokenJson != null) {
        _rawTokenStr = rawTokenJson;
        try {
          _rawTokenData = jsonDecode(rawTokenJson) as Map<String, dynamic>;
        } catch (e) {
          _log.log('Error decoding rawToken: $e');
        }
      }
      _isLoggedIn = true;
      _fetchUserInfo(accessToken);
    }
  }

  Future<void> _fetchUserInfo(String token) async {
    try {
      final userResult = await getUserUseCase(token);
      userResult.fold(
        (f) => _log.log('Failed to fetch user info: ${f.message}'),
        (u) {
          // Map Domain User to Model User
          _currentUser = UserModel(
            studentId: u.studentId,
            fullName: u.fullName,
            email: u.email,
            profileImageUrl: u.profileImageUrl,
          );
          notifyListeners();
        },
      );
    } catch (e) {
      _log.log('Error fetching user info: $e');
    }
  }

  /// Login with student code and password (Clean Arch)
  Future<bool> login(String studentCode, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _loginProgress = 'Đang đăng nhập...';
    _loginProgressPercent = 0.2;
    notifyListeners();

    try {
      final result = await loginUseCase(
        LoginParams(studentCode: studentCode, password: password),
      );

      return await result.fold(
        (failure) async {
          _errorMessage = failure.message;
          _isLoading = false;
          notifyListeners();
          return false;
        },
        (tokenData) async {
          _accessToken = tokenData['access_token'];
          _rawTokenData = tokenData;
          _isLoggedIn = true;
          await _prefs.setString(_accessTokenKey, _accessToken!);

          final tokenStr = jsonEncode(tokenData);
          _rawTokenStr = tokenStr;
          await _prefs.setString('rawToken', tokenStr);

          // Save credentials for auto-relogin
          await _storage.write(key: 'studentCode', value: studentCode);
          await _storage.write(key: 'password', value: password);

          // Save other token fields if needed, or serialize the whole map
          // For simplicity, we just keep it in memory. If app restarts, we might lose refresh_token
          // if we don't save it. For now, let's just make it work for the session.

          // Ideally: await _prefs.setString('rawToken', jsonEncode(tokenData));

          // Fetch User Info
          _loginProgress = 'Đang lấy thông tin sinh viên...';
          _loginProgressPercent = 0.5;
          notifyListeners();

          await _fetchUserInfo(_accessToken!);

          // Trigger immediate data sync for offline usage
          _loginProgress = 'Đang đồng bộ dữ liệu...';
          _loginProgressPercent = 0.8;
          notifyListeners();

          // We call the service to fetch and cache Schedule & Exams
          // This ensures that right after login, we have data.
          await AutoRefreshService.triggerRefresh();

          _isLoading = false;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool>? _reLoginFuture;

  /// Attempts to re-login using stored credentials
  /// returns true if successful, false otherwise.
  /// Retries up to 3 times.
  /// Handles concurrent calls by returning the same future.
  Future<bool> reLogin() {
    if (_reLoginFuture != null) {
      _log.log('Joining existing re-login attempt');
      return _reLoginFuture!;
    }

    _reLoginFuture = _performReLogin();
    return _reLoginFuture!.whenComplete(() {
      _reLoginFuture = null;
    });
  }

  Future<bool> _performReLogin() async {
    // Avoid concurrent relogin attempts if simple login is happening?
    // Using simple _isLoading check might block valid retry if UI is busy?
    // Let's rely on _reLoginFuture deduplication.

    final studentCode = await _storage.read(key: 'studentCode');
    final password = await _storage.read(key: 'password');

    if (studentCode == null || password == null) {
      _log.log('No stored credentials for auto-relogin');
      return false;
    }

    _log.log('Auto-relogin started for user: $studentCode');

    for (int i = 0; i < 3; i++) {
      _log.log('Auto-relogin attempt ${i + 1}/3');
      // login() handles state updates (_isLoading, _errorMessage, etc.)
      final success = await login(studentCode, password);

      if (success) {
        _log.log('Auto-relogin success!');
        return true;
      }

      // Wait a bit before retrying
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    _log.log('Auto-relogin failed after 3 attempts');
    return false;
  }

  Future<void> logout() async {
    _accessToken = null;
    _isLoggedIn = false;
    _currentUser = null;
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove('rawToken');
    await _storage.deleteAll();
    _rawTokenData = null;
    _rawTokenStr = null;
    notifyListeners();
  }
}
