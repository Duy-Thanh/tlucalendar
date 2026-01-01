import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';
import 'package:timezone/timezone.dart' as tz;

class CalendarSyncService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin =
      DeviceCalendarPlugin();
  static const String _calendarName = 'TLU Calendar';

  /// Syncs a list of courses to the device calendar.
  /// [courseHours] is used to map period numbers to actual times.
  static Future<String> exportScheduleToCalendar(
    List<Course> courses,
    List<CourseHour> courseHours, {
    Color? calendarColor,
  }) async {
    if (courses.isEmpty) return "Không có lịch học để đồng bộ.";

    final calendarId = await _getOrCreateCalendar(calendarColor);
    if (calendarId == null) {
      throw "Không thể tạo hoặc tìm thấy lịch '$_calendarName'.";
    }

    int successCount = 0;
    int failCount = 0;

    for (final course in courses) {
      try {
        await _createCourseEvent(calendarId, course, courseHours);
        successCount++;
      } catch (e) {
        debugPrint("Error syncing course ${course.courseCode}: $e");
        failCount++;
      }
    }

    return "Đã đồng bộ $successCount môn học${failCount > 0 ? ' ($failCount lỗi)' : ''}.";
  }

  /// Syncs a list of exam rooms to the device calendar.
  static Future<String> exportExamToCalendar(
    List<ExamRoom> exams, {
    Color? calendarColor,
  }) async {
    if (exams.isEmpty) return "Không có lịch thi để đồng bộ.";

    final calendarId = await _getOrCreateCalendar(calendarColor);
    if (calendarId == null) {
      throw "Không thể tạo hoặc tìm thấy lịch '$_calendarName'.";
    }

    int successCount = 0;

    for (final exam in exams) {
      if (exam.examDate == null || exam.examTime == null) continue;

      try {
        final parsed = _parseExamDateTimeDetails(
          exam.examDate!,
          exam.examTime!,
        );
        final startTime = parsed['start']!;
        final endTime = parsed['end']!;

        final event = Event(calendarId);
        event.title = "Thi: ${exam.subjectName}";
        event.description =
            "Phòng: ${exam.roomName ?? 'Unknown'}\nSBD: ${exam.studentCode ?? 'N/A'}\nGhi chú: ${exam.notes ?? ''} ${exam.examMethod ?? ''}";
        event.start = tz.TZDateTime.from(startTime, tz.local);
        event.end = tz.TZDateTime.from(endTime, tz.local);
        event.location = exam.roomName;
        // event.reminders = [Reminder(minutes: 60)]; // Remind 1 hour before

        final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
        if (result?.isSuccess == true) {
          successCount++;
        }
      } catch (e) {
        debugPrint("Error syncing exam ${exam.subjectName}: $e");
      }
    }

    return "Đã đồng bộ $successCount lịch thi.";
  }

  // --- Helpers ---

  static Future<String?> _getOrCreateCalendar(Color? calendarColor) async {
    // 1. Check Permissions
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        throw "Quyền truy cập lịch bị từ chối.";
      }
    }

    // 2. Find existing
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      for (final cal in calendarsResult.data!) {
        if (cal.name == _calendarName && !cal.isReadOnly!) {
          return cal.id;
        }
      }
    }

    // 3. Create new
    final createResult = await _deviceCalendarPlugin.createCalendar(
      _calendarName,
      calendarColor: calendarColor ?? Colors.blue,
      localAccountName: _calendarName,
    );

    if (createResult.isSuccess && createResult.data != null) {
      return createResult.data;
    }

    return null;
  }

  static Future<void> _createCourseEvent(
    String calendarId,
    Course course,
    List<CourseHour> courseHours,
  ) async {
    // 1. Calculate Start/End Date from Course
    final validFrom = DateTime.fromMillisecondsSinceEpoch(course.startDate);
    final validTo = DateTime.fromMillisecondsSinceEpoch(course.endDate);

    // 2. Adjust validFrom to the first actual day of class
    // TLU: 2=Mon...8=Sun. Dart: 1=Mon...7=Sun.
    // Convert TLU day to Dart day: TLU - 1
    int targetWeekday = course.dayOfWeek - 1;
    if (targetWeekday == 0)
      targetWeekday =
          7; // Handle TLU 8 (Sun) -> Dart 7? -> No TLU 8 is Sun, 8-1=7. Correct.
    // Wait: TLU Monday is 2. 2-1 = 1 (Mon). Correct.
    // TLU Sunday is 8. 8-1 = 7 (Sun). Correct.

    // Find difference
    int daysDiff = targetWeekday - validFrom.weekday;
    if (daysDiff < 0) daysDiff += 7;

    final firstClassDate = validFrom.add(Duration(days: daysDiff));
    if (firstClassDate.isAfter(validTo)) {
      // Course validity too short or something wrong
      return;
    }

    // 3. Calculate Time
    final startHourModel = _findCourseHour(courseHours, course.startCourseHour);
    final endHourModel = _findCourseHour(courseHours, course.endCourseHour);

    final startTimeParts = startHourModel.startString.split(':');
    final endTimeParts = endHourModel.endString.split(':');

    final startDateTime = DateTime(
      firstClassDate.year,
      firstClassDate.month,
      firstClassDate.day,
      int.parse(startTimeParts[0]),
      int.parse(startTimeParts[1]),
    );
    final endDateTime = DateTime(
      firstClassDate.year,
      firstClassDate.month,
      firstClassDate.day,
      int.parse(endTimeParts[0]),
      int.parse(endTimeParts[1]),
    );

    // 4. Create Event
    final event = Event(calendarId);
    event.title = "${course.courseName} (${course.courseCode})";
    event.description =
        "Phòng: ${course.room}\nGV: ${course.lecturerName ?? 'N/A'}";
    event.location = course.room;
    event.start = tz.TZDateTime.from(startDateTime, tz.local);
    event.end = tz.TZDateTime.from(endDateTime, tz.local);

    // Recurrence
    event.recurrenceRule = RecurrenceRule(
      RecurrenceFrequency.Weekly,
      endDate: tz.TZDateTime.from(
        validTo.add(const Duration(days: 1)),
        tz.local,
      ), // Include end date
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    if (result?.isSuccess != true) {
      throw result?.errors.join(', ') ?? 'Unknown error';
    }
  }

  static CourseHour _findCourseHour(List<CourseHour> hours, int index) {
    // Try finding in list
    try {
      return hours.firstWhere((h) => h.indexNumber == index);
    } catch (_) {
      // Fallback default TLU hours
      return _getDefaultCourseHour(index);
    }
  }

  static CourseHour _getDefaultCourseHour(int index) {
    // Simplified default map
    final map = {
      1: ["07:00", "07:50"],
      2: ["07:55", "08:45"],
      3: ["08:50", "09:40"],
      4: ["09:45", "10:35"],
      5: ["10:40", "11:30"],
      6: ["11:35", "12:25"],
      7: ["12:30", "13:20"],
      8: ["13:25", "14:15"],
      9: ["14:20", "15:10"],
      10: ["15:15", "16:05"],
      11: ["16:10", "17:00"],
      12: ["17:05", "17:55"],
      13: ["18:00", "18:50"],
      14: ["18:55", "19:45"],
      15: ["19:50", "20:40"],
      16: ["20:45", "21:35"],
    };

    final times = map[index] ?? ["00:00", "01:00"];
    return CourseHour(
      id: index,
      name: "Tiết $index",
      startString: times[0],
      endString: times[1],
      indexNumber: index,
    );
  }

  static Map<String, DateTime> _parseExamDateTimeDetails(
    DateTime date,
    String timeStr,
  ) {
    // Default duration
    const defaultDuration = Duration(minutes: 60);

    // Normalize string
    final cleanStr = timeStr.trim();

    int startHour = 7;
    int startMinute = 0;
    int endHour = 8;
    int endMinute = 0;
    bool hasEnd = false;

    // Pattern 1: Range "07:00 - 09:00" or "07:00-09:00"
    if (cleanStr.contains(':')) {
      final parts = cleanStr.split(RegExp(r'\s*-\s*'));
      if (parts.isNotEmpty) {
        final startParts = parts[0].split(':');
        if (startParts.length >= 2) {
          startHour = int.tryParse(startParts[0]) ?? 7;
          startMinute = int.tryParse(startParts[1]) ?? 0;
        }

        if (parts.length >= 2) {
          final endParts = parts[1].split(':');
          if (endParts.length >= 2) {
            endHour = int.tryParse(endParts[0]) ?? (startHour + 1);
            endMinute = int.tryParse(endParts[1]) ?? startMinute;
            hasEnd = true;
          }
        }
      }
    }
    // Pattern 2: "Ca X"
    else if (cleanStr.toLowerCase().contains("ca")) {
      if (cleanStr.contains("1")) {
        startHour = 7;
        startMinute = 0;
      } else if (cleanStr.contains("2")) {
        startHour = 9;
        startMinute = 30;
      } else if (cleanStr.contains("3")) {
        startHour = 13;
        startMinute = 0;
      } else if (cleanStr.contains("4")) {
        startHour = 15;
        startMinute = 30;
      }
    }

    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      startHour,
      startMinute,
    );
    final endTime = hasEnd
        ? DateTime(date.year, date.month, date.day, endHour, endMinute)
        : startTime.add(defaultDuration);

    return {'start': startTime, 'end': endTime};
  }
}
