import 'package:flutter/material.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/grades/domain/entities/student_mark.dart';
import 'package:tlucalendar/features/grades/domain/usecases/get_grades.dart';

class GradeProvider extends ChangeNotifier {
  final GetGrades getGradesUseCase;

  GradeProvider({required this.getGradesUseCase});

  List<StudentMark> _grades = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<StudentMark> get grades => _grades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Grouped by Semester: Map<SemesterName, List<StudentMark>>
  Map<String, List<StudentMark>> get groupedGrades {
    final Map<String, List<StudentMark>> grouped = {};
    for (var grade in _grades) {
      if (!grouped.containsKey(grade.semesterName)) {
        grouped[grade.semesterName] = [];
      }
      grouped[grade.semesterName]!.add(grade);
    }
    return grouped;
  }

  Future<void> fetchGrades(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getGradesUseCase(
      GetGradesParams(accessToken: accessToken),
    );

    result.fold(
      (failure) {
        _errorMessage = _mapFailureToMessage(failure);
        _isLoading = false;
        notifyListeners();
      },
      (grades) {
        _grades = grades;
        _grades.sort((a, b) => b.semesterId.compareTo(a.semesterId));
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.message;
    } else {
      return 'Unexpected Error';
    }
  }
}
