import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final int id;
  final String courseCode;
  final String courseName;
  final String? classCode;
  final String? className;
  final int dayOfWeek; // 2=Monday, 8=Sunday
  final int startCourseHour; // 1-15
  final int endCourseHour; // 1-15
  final String room;
  final String? building;
  final String? campus;
  final int credits;
  final int startDate; // ms since epoch
  final int endDate; // ms since epoch
  final int fromWeek;
  final int toWeek;
  final String? lecturerName;
  final String? lecturerEmail;
  final String status;
  final double? grade;

  const Course({
    required this.id,
    required this.courseCode,
    required this.courseName,
    this.classCode,
    this.className,
    required this.dayOfWeek,
    required this.startCourseHour,
    required this.endCourseHour,
    required this.room,
    this.building,
    this.campus,
    required this.credits,
    required this.startDate,
    required this.endDate,
    required this.fromWeek,
    required this.toWeek,
    this.lecturerName,
    this.lecturerEmail,
    required this.status,
    this.grade,
  });

  /// Check if course is active on a specific date
  bool isActiveOn(DateTime date) {
    // Only check date range here.
    // TimeProvider/Utils should handle "is today" logic.
    final checkDate = DateTime(date.year, date.month, date.day);

    final courseStart = DateTime.fromMillisecondsSinceEpoch(startDate);
    final courseStartDate = DateTime(
      courseStart.year,
      courseStart.month,
      courseStart.day,
    );

    final courseEnd = DateTime.fromMillisecondsSinceEpoch(endDate);
    final courseEndDate = DateTime(
      courseEnd.year,
      courseEnd.month,
      courseEnd.day,
    );

    return !checkDate.isBefore(courseStartDate) &&
        !checkDate.isAfter(courseEndDate);
  }

  @override
  List<Object?> get props => [
    id,
    courseCode,
    courseName,
    dayOfWeek,
    startCourseHour,
    endCourseHour,
    room,
    startDate,
    endDate,
    fromWeek,
    toWeek,
  ];
}
