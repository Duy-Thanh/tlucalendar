import 'package:equatable/equatable.dart';

class ExamRoom extends Equatable {
  final int id;
  final String subjectName;
  final String examPeriodCode;
  final String? studentCode;
  final DateTime? examDate;
  final String? examTime; // e.g. "07:00"
  final String? roomName;
  final String? roomBuilding;
  final String? examMethod; // e.g. "Vấn đáp"
  final String? notes;
  final int? numberExpectedStudent;

  const ExamRoom({
    required this.id,
    required this.subjectName,
    required this.examPeriodCode,
    this.studentCode,
    this.examDate,
    this.examTime,
    this.roomName,
    this.roomBuilding,
    this.examMethod,
    this.notes,
    this.numberExpectedStudent,
  });

  @override
  List<Object?> get props => [
    id,
    subjectName,
    examPeriodCode,
    examDate,
    roomName,
    numberExpectedStudent,
  ];
}
