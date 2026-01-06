import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';

class SubjectRegistrationModel extends SubjectRegistration {
  const SubjectRegistrationModel({
    required super.subjectName,
    required super.numberOfCredit,
    required super.courseSubjects,
  });
}

class CourseSubjectModel extends CourseSubject {
  const CourseSubjectModel({
    required super.id,
    required super.code,
    required super.name,
    required super.displayCode,
    required super.numberStudent,
    required super.maxStudent,
    required super.isSelected,
    required super.isFull,
    required super.isOverlap,
    required super.credits,
    required super.status,
    required super.timetables,
  });
}

class TimetableModel extends Timetable {
  const TimetableModel({
    required super.id,
    required super.startDate,
    required super.endDate,
    required super.fromWeek,
    required super.toWeek,
    required super.dayOfWeek,
    required super.startHour,
    required super.endHour,
    required super.roomName,
    required super.teacherName,
  });
}
