import 'package:equatable/equatable.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester_register_period.dart';

class Semester extends Equatable {
  final int id;
  final String semesterCode;
  final String semesterName;
  final int startDate;
  final int endDate;
  final bool isCurrent;
  final int? ordinalNumbers;
  final List<SemesterRegisterPeriod>? registerPeriods;

  const Semester({
    required this.id,
    required this.semesterCode,
    required this.semesterName,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    this.ordinalNumbers,
    this.registerPeriods,
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
    isCurrent,
    ordinalNumbers,
    registerPeriods,
  ];
}
