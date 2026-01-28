import 'package:tlucalendar/features/grades/domain/entities/student_mark.dart';

class StudentMarkModel extends StudentMark {
  const StudentMarkModel({
    required super.subjectCode,
    required super.subjectName,
    required super.numberOfCredit,
    required super.mark,
    required super.markQT,
    required super.markTHI,
    required super.charMark,
    required super.studyTime,
    required super.examRound,
    required super.isCalculateMark,
    required super.semesterCode,
    required super.semesterName,
    required super.semesterId,
  });

  // Factory/FromJson isn't strictly needed for Native parsing as we map manually,
  // but good to have if we ever parse pure Dart JSON.
  // For now, I'll rely on the constructor.
}
