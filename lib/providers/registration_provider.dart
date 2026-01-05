import 'package:flutter/material.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';
import 'package:tlucalendar/features/registration/domain/usecases/cancel_course.dart';
import 'package:tlucalendar/features/registration/domain/usecases/get_registration_data.dart';
import 'package:tlucalendar/features/registration/domain/usecases/register_course.dart';
import 'package:tlucalendar/providers/auth_provider.dart';

class RegistrationProvider extends ChangeNotifier {
  final GetRegistrationData getRegistrationData;
  final RegisterCourse registerCourse;
  final CancelCourse cancelCourse;

  RegistrationProvider({
    required this.getRegistrationData,
    required this.registerCourse,
    required this.cancelCourse,
  });

  AuthProvider? _authProvider;

  void setAuthProvider(AuthProvider auth) {
    _authProvider = auth;
  }

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<SubjectRegistration> _subjects = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SubjectRegistration> get subjects => _subjects;

  String? get _userPersonId {
    return _authProvider?.currentUser?.id?.toString();
  }

  Future<void> fetchRegistrationData(String periodId) async {
    final personId = _userPersonId;
    if (personId == null) {
      _errorMessage = "Chưa đăng nhập"; // User not logged in
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getRegistrationData(personId, periodId);

    result.fold(
      (failure) {
        _errorMessage = _mapFailureToMessage(failure);
        _subjects = [];
      },
      (data) {
        _subjects = data;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> registerSubject(String periodId, String payload) async {
    final personId = _userPersonId;
    if (personId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await registerCourse(personId, periodId, payload);

    bool success = false;
    result.fold(
      (failure) {
        _errorMessage = _mapFailureToMessage(failure);
      },
      (_) {
        success = true;
      },
    );

    if (!success) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Refresh
    await fetchRegistrationData(periodId);
    return true;
  }

  Future<bool> cancelSubjectRegistration(
    String periodId,
    String payload,
  ) async {
    final personId = _userPersonId;
    if (personId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await cancelCourse(personId, periodId, payload);

    bool success = false;
    result.fold(
      (failure) {
        _errorMessage = _mapFailureToMessage(failure);
      },
      (_) {
        success = true;
      },
    );

    if (!success) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    await fetchRegistrationData(periodId);
    return true;
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.message;
    } else if (failure is CacheFailure) {
      return failure.message;
    } else {
      return 'Unexpected error';
    }
  }
}
