import 'package:equatable/equatable.dart';

class SubjectRegistration extends Equatable {
  final String subjectName;
  final int numberOfCredit;
  final List<CourseSubject> courseSubjects;

  const SubjectRegistration({
    required this.subjectName,
    required this.numberOfCredit,
    required this.courseSubjects,
  });

  @override
  List<Object?> get props => [subjectName, numberOfCredit, courseSubjects];
}

class CourseSubject extends Equatable {
  final int id;
  final String code;
  final String name; // Usually same as subjectName
  final String displayCode;
  final int numberStudent;
  final int maxStudent;
  final bool isSelected;
  final bool isFull;
  final bool isOverlap;
  final int credits;
  final String status;
  final List<Timetable> timetables;

  const CourseSubject({
    required this.id,
    required this.code,
    required this.name,
    required this.displayCode,
    required this.numberStudent,
    required this.maxStudent,
    required this.isSelected,
    required this.isFull,
    required this.isOverlap,
    required this.credits,
    required this.status,
    required this.timetables,
  });

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    displayCode,
    numberStudent,
    maxStudent,
    isSelected,
    isFull,
    isOverlap,
    credits,
    status,
    timetables,
  ];
}

class Timetable extends Equatable {
  final int id;
  final int startDate;
  final int endDate;
  final int fromWeek;
  final int toWeek;
  final int dayOfWeek;
  final int startHour;
  final int endHour;
  final String roomName;
  final String teacherName;

  const Timetable({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.fromWeek,
    required this.toWeek,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.roomName,
    required this.teacherName,
  });

  @override
  List<Object?> get props => [
    id,
    startDate,
    endDate,
    fromWeek,
    toWeek,
    dayOfWeek,
    startHour,
    endHour,
    roomName,
    teacherName,
  ];
}
