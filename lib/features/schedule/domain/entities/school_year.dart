import 'package:equatable/equatable.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';

class SchoolYear extends Equatable {
  final int id;
  final String name;
  final String code;
  final int year;
  final bool current;
  final int startDate;
  final int endDate;
  final String displayName;
  final List<Semester> semesters;

  const SchoolYear({
    required this.id,
    required this.name,
    required this.code,
    required this.year,
    required this.current,
    required this.startDate,
    required this.endDate,
    required this.displayName,
    required this.semesters,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    code,
    year,
    current,
    startDate,
    endDate,
    displayName,
    semesters,
  ];
}
