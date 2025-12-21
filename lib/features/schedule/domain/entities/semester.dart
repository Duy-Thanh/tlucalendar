import 'package:equatable/equatable.dart';

class Semester extends Equatable {
  final int id;
  final String semesterCode;
  final String semesterName;
  final int startDate;
  final int endDate;
  final bool isCurrent;
  final int? ordinalNumbers;
  // Note: RegisterPeriod related fields might be added if needed,
  // but for Schedule feature basics, these are sufficient.
  // We keep it simple for now matching existing usage.

  const Semester({
    required this.id,
    required this.semesterCode,
    required this.semesterName,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    this.ordinalNumbers,
  });

  @override
  List<Object?> get props => [
    id,
    semesterCode,
    semesterName,
    startDate,
    endDate,
    isCurrent,
    ordinalNumbers,
  ];
}
