import 'package:tlucalendar/features/schedule/domain/entities/course.dart';

class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.courseCode,
    required super.courseName,
    super.classCode,
    super.className,
    required super.dayOfWeek,
    required super.startCourseHour,
    required super.endCourseHour,
    required super.room,
    super.building,
    super.campus,
    required super.credits,
    required super.startDate,
    required super.endDate,
    required super.fromWeek,
    required super.toWeek,
    super.lecturerName,
    super.lecturerEmail,
    required super.status,
    super.grade,
  });

  /// Factory to convert from JSON
  /// Logic adapted from `StudentCourseSubject.fromJson` but kept cleaner
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int from various types
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is double) return value.toInt();
      return defaultValue;
    }

    // Helper to safely convert any value to string
    String toString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }

    Map<String, dynamic> courseSubjectData = {};
    if (json['courseSubject'] is Map) {
      courseSubjectData = json['courseSubject'];
    }

    int startHour = 0;
    int endHour = 0;
    int dayOfWeek = -1;
    String room = '';
    String building = '';
    String campus = '';
    int fromWeek = 1;
    int toWeek = 1;
    int timetableStartDate = 0;
    int timetableEndDate = 0;

    // Try to get schedule from timetables array (first entry if exists)
    // Note: The original logic handled multiple timetables by expanding them.
    // Here we assume the input JSON is already an expanded item or we pick the first.
    // Ideally, the DataSource should expand the list before creating Models.
    if (courseSubjectData['timetables'] is List &&
        (courseSubjectData['timetables'] as List).isNotEmpty) {
      final timetable = courseSubjectData['timetables'][0];
      if (timetable is Map) {
        // Parse start/end hour
        // StartHour
        var startHourObj = timetable['startHour'];
        if (startHourObj is Map) {
          startHour = parseInt(startHourObj['id']);
        } else if (timetable['startCourseHour'] is Map) {
          startHour = parseInt(timetable['startCourseHour']['id']);
        } else {
          startHour = parseInt(startHourObj ?? timetable['startTime']);
        }

        // EndHour
        var endHourObj = timetable['endHour'];
        if (endHourObj is Map) {
          endHour = parseInt(endHourObj['id']);
        } else if (timetable['endCourseHour'] is Map) {
          endHour = parseInt(timetable['endCourseHour']['id']);
        } else {
          endHour = parseInt(endHourObj ?? timetable['endTime']);
        }

        dayOfWeek = parseInt(timetable['weekIndex']);
        fromWeek = parseInt(timetable['fromWeek'], defaultValue: 1);
        toWeek = parseInt(timetable['toWeek'], defaultValue: 1);
        timetableStartDate = parseInt(timetable['startDate']);
        timetableEndDate = parseInt(timetable['endDate']);

        if (timetable['room'] is Map) {
          room = toString(timetable['room']['name']);
          building = toString(timetable['room']['building']);
        } else {
          room = toString(timetable['room']);
          building = toString(timetable['building']);
        }
        campus = toString(timetable['campus']);
      }
    }

    // Fallbacks
    if (startHour == 0 && courseSubjectData['startCourseHour'] != null) {
      if (courseSubjectData['startCourseHour'] is Map) {
        startHour = parseInt(courseSubjectData['startCourseHour']['id']);
      } else {
        startHour = parseInt(courseSubjectData['startCourseHour']);
      }
    }

    if (endHour == 0 && courseSubjectData['endCourseHour'] != null) {
      if (courseSubjectData['endCourseHour'] is Map) {
        endHour = parseInt(courseSubjectData['endCourseHour']['id']);
      } else {
        endHour = parseInt(courseSubjectData['endCourseHour']);
      }
    }

    if (dayOfWeek == -1 && courseSubjectData['dayOfWeek'] != null) {
      dayOfWeek = parseInt(courseSubjectData['dayOfWeek']);
    }

    if (room.isEmpty && courseSubjectData['room'] != null) {
      room = toString(courseSubjectData['room']);
    }

    final credits = parseInt(
      json['numberOfCredit'] ?? json['credits'] ?? json['credit'],
    );
    final courseName = toString(json['subjectName'] ?? json['courseName']);
    final courseCode = toString(json['subjectCode'] ?? json['courseCode']);

    // Lecturer info
    String? lecturerName;
    String? lecturerEmail;
    if (courseSubjectData['lecturer'] != null &&
        courseSubjectData['lecturer'] is Map) {
      lecturerName = courseSubjectData['lecturer']['name'];
      lecturerEmail = courseSubjectData['lecturer']['email'];
    }

    return CourseModel(
      id: parseInt(json['id']),
      courseCode: courseCode,
      courseName: courseName,
      classCode: toString(courseSubjectData['classCode']),
      className: toString(courseSubjectData['className']),
      dayOfWeek: dayOfWeek,
      startCourseHour: startHour,
      endCourseHour: endHour,
      room: room,
      building: building,
      campus: campus,
      credits: credits,
      startDate: timetableStartDate > 0
          ? timetableStartDate
          : parseInt(json['startDate']),
      endDate: timetableEndDate > 0
          ? timetableEndDate
          : parseInt(json['endDate']),
      fromWeek: fromWeek,
      toWeek: toWeek,
      lecturerName: lecturerName,
      lecturerEmail: lecturerEmail,
      status: toString(json['status']),
      grade: json['grade'] != null
          ? double.tryParse(toString(json['grade']))
          : null,
    );
  }
}
