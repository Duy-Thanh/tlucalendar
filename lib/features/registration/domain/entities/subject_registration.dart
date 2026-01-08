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

  SubjectRegistration copyWith({
    String? subjectName,
    int? numberOfCredit,
    List<CourseSubject>? courseSubjects,
  }) {
    return SubjectRegistration(
      subjectName: subjectName ?? this.subjectName,
      numberOfCredit: numberOfCredit ?? this.numberOfCredit,
      courseSubjects: courseSubjects ?? this.courseSubjects,
    );
  }
}

class CourseSubject extends Equatable {
  final int id;
  final int subjectId; // Added
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
    required this.subjectId,
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

  CourseSubject copyWith({
    int? id,
    int? subjectId,
    String? code,
    String? name,
    String? displayCode,
    int? numberStudent,
    int? maxStudent,
    bool? isSelected,
    bool? isFull,
    bool? isOverlap,
    int? credits,
    String? status,
    List<Timetable>? timetables,
  }) {
    return CourseSubject(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      code: code ?? this.code,
      name: name ?? this.name,
      displayCode: displayCode ?? this.displayCode,
      numberStudent: numberStudent ?? this.numberStudent,
      maxStudent: maxStudent ?? this.maxStudent,
      isSelected: isSelected ?? this.isSelected,
      isFull: isFull ?? this.isFull,
      isOverlap: isOverlap ?? this.isOverlap,
      credits: credits ?? this.credits,
      status: status ?? this.status,
      timetables: timetables ?? this.timetables,
    );
  }
}

class Timetable extends Equatable {
  final int id;
  final int roomId;
  final int startHourId;
  final int endHourId;
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
    required this.roomId,
    required this.startHourId,
    required this.endHourId,
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
    roomId,
    startHourId,
    endHourId,
    roomName,
    teacherName,
  ];
}
