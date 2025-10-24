import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/models/user.dart';

class UserProvider extends ChangeNotifier {
  late User _currentUser;
  late SharedPreferences _prefs;
  bool _isLoggedIn = false;

  static const String _studentCodeKey = 'userStudentCode';
  static const String _passwordKey = 'userPassword';
  static const String _isLoggedInKey = 'isLoggedIn';

  User get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  UserProvider() {
    // Initialize with sample user
    _currentUser = User(
      studentId: '2251061884',
      fullName: 'Nekkochan',
      email: 'nekkochan@tlu.edu.vn',
    );
  }

  /// Initialize SharedPreferences and load saved login credentials
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isLoggedIn = _prefs.getBool(_isLoggedInKey) ?? false;
    
    // Load saved student code if logged in
    if (_isLoggedIn) {
      final savedStudentCode = _prefs.getString(_studentCodeKey) ?? _currentUser.studentId;
      _currentUser = User(
        studentId: savedStudentCode,
        fullName: _currentUser.fullName,
        email: _currentUser.email,
      );
    }
    notifyListeners();
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Update only the student code
  void updateUserStudentCode(String studentCode) {
    _currentUser = User(
      studentId: studentCode,
      fullName: _currentUser.fullName,
      email: _currentUser.email,
    );
    notifyListeners();
  }

  /// Update only the email
  void updateUserEmail(String email) {
    _currentUser = User(
      studentId: _currentUser.studentId,
      fullName: _currentUser.fullName,
      email: email,
    );
    notifyListeners();
  }

  /// Save login credentials to SharedPreferences (using student code instead of email)
  Future<void> saveLoginCredentials(String studentCode, String password) async {
    await _prefs.setString(_studentCodeKey, studentCode);
    await _prefs.setString(_passwordKey, password);
    await _prefs.setBool(_isLoggedInKey, true);
    _isLoggedIn = true;
    updateUserStudentCode(studentCode);
  }

  /// Log out and clear saved credentials
  Future<void> logout() async {
    await _prefs.remove(_studentCodeKey);
    await _prefs.remove(_passwordKey);
    await _prefs.setBool(_isLoggedInKey, false);
    _isLoggedIn = false;
    
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

