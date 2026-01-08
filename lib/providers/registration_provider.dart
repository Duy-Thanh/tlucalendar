import 'dart:convert';
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
    final token = _authProvider?.accessToken;
    if (personId == null || token == null) {
      _errorMessage = "Chưa đăng nhập"; // User not logged in
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getRegistrationData(personId, periodId, token);

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
    final token = _authProvider?.accessToken;
    if (personId == null || token == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await registerCourse(personId, periodId, payload, token);

    bool success = false;
    // Check for Review Mode Signal or Real Error
    bool isReviewMode = false;
    result.fold(
      (failure) {
        if (failure is ReviewModeSuccessFailure) {
          isReviewMode = true;
          success = true; // Treat as success
          _handleOptimisticUpdate(payload, isRegister: true);
        } else {
          _errorMessage = _mapFailureToMessage(failure);
        }
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

    // Refresh only if NOT in Review Mode (Real server update)
    if (!isReviewMode) {
      await fetchRegistrationData(periodId);
    } else {
      _isLoading = false;
      notifyListeners();
    }
    return true;
  }

  Future<bool> cancelSubjectRegistration(
    String periodId,
    String payload,
  ) async {
    final personId = _userPersonId;
    final token = _authProvider?.accessToken;
    if (personId == null || token == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await cancelCourse(personId, periodId, payload, token);

    bool success = false;
    bool isReviewMode = false;
    result.fold(
      (failure) {
        if (failure is ReviewModeSuccessFailure) {
          isReviewMode = true;
          success = true;
          _handleOptimisticUpdate(payload, isRegister: false);
        } else {
          _errorMessage = _mapFailureToMessage(failure);
        }
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

    if (!isReviewMode) {
      await fetchRegistrationData(periodId);
    } else {
      _isLoading = false;
      notifyListeners();
    }
    return true;
  }

  void _handleOptimisticUpdate(String payload, {required bool isRegister}) {
    try {
      final Map<String, dynamic> json = jsonDecode(payload);

      // Extract subjectId (which is the main ID in payload)
      // Note: In Register payload, 'id' is often the CourseSubject ID.
      // In Cancel payload, 'id' IS the CourseSubject ID.
      // Based on payload structure: "id": 53282 (CourseSubject ID), "subjectId": 1418 ...
      final int? courseSubjectId = json['id'];

      if (courseSubjectId == null) return;

      // Re-map the _subjects list to create a new state
      _subjects = _subjects.map((sub) {
        bool changed = false;
        final newCourseSubjects = sub.courseSubjects.map((cs) {
          if (cs.id == courseSubjectId) {
            changed = true;
            // Toggle selection based on action
            return cs.copyWith(isSelected: isRegister);
          }
          return cs;
        }).toList();

        if (changed) {
          return sub.copyWith(courseSubjects: newCourseSubjects);
        }
        return sub;
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Optimistic Update Failed: $e");
    }
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
