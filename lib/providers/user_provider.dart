import 'package:flutter/material.dart';
import 'package:tlucalendar/models/user.dart';

class UserProvider extends ChangeNotifier {
  late User _currentUser;

  User get currentUser => _currentUser;

  UserProvider() {
    // Initialize with sample user
    _currentUser = User(
      studentId: '2251061884',
      fullName: 'Nekkochan',
      email: 'nekkochan@tlu.edu.vn',
    );
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
