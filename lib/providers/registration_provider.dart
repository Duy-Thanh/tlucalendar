import 'package:flutter/material.dart';
import 'package:tlucalendar/providers/auth_provider.dart';

class RegistrationProvider extends ChangeNotifier {
  AuthProvider? _authProvider;

  void setAuthProvider(AuthProvider auth) {
    _authProvider = auth;
  }

  // State
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Init
  Future<void> init() async {
    // Scaffold
  }
}
