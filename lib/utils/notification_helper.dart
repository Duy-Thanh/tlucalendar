import 'package:tlucalendar/services/notification_service.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/exam/data/models/exam_dtos.dart' as Legacy;

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();
  static final _log = LogService();

  static Future<void> scheduleWeekClassNotifications({
    required List<CourseModel> courses,
    required Map<int, CourseHour> courseHours,
    required DateTime weekStartDate,
    required DateTime semesterStartDate,
  }) async {
    final now = DateTime.now();

    for (final course in courses) {
      if (!_isActiveOn(course, weekStartDate, semesterStartDate)) {
        continue;
      }

      final apiDayOfWeek = course.dayOfWeek;
      final dayOfWeek = apiDayOfWeek - 2;

      final classDate = weekStartDate.add(Duration(days: dayOfWeek));

      if (classDate.isBefore(now) && !_isSameDay(classDate, now)) {
        continue;
      }

      final startCourseHour = courseHours[course.startCourseHour];
      if (startCourseHour == null) {
        _log.log(
          'No start course hour found for ID: ${course.startCourseHour}',
          level: LogLevel.warning,
        );
        continue;
      }

      final endCourseHour = courseHours[course.endCourseHour];
      if (endCourseHour == null) {
        _log.log(
          'No end course hour found for ID: ${course.endCourseHour}',
          level: LogLevel.warning,
        );
        continue;
      }

      final startParts = startCourseHour.startString.split(':');
      if (startParts.length != 2) {
        _log.log(
          'Invalid start time format: ${startCourseHour.startString}',
          level: LogLevel.warning,
        );
        continue;
      }

      final hour = int.tryParse(startParts[0]);
      final minute = int.tryParse(startParts[1]);
      if (hour == null || minute == null) {
        _log.log(
          'Could not parse hour/minute from: ${startCourseHour.startString}',
          level: LogLevel.warning,
        );
        continue;
      }

      final classDateTime = DateTime(
        classDate.year,
        classDate.month,
        classDate.day,
        hour,
        minute,
      );

      if (classDateTime.year > now.year + 10 || classDateTime.year < 2020) {
        _log.log(
          'Invalid class date year: ${classDateTime.year} - SKIPPING',
          level: LogLevel.warning,
        );
        continue;
      }

      final timeSlot =
          '${startCourseHour.startString} - ${endCourseHour.endString}';

      await _notificationService.scheduleClassNotifications(
        course,
        classDateTime,
        dayOfWeek + 2,
        timeSlot,
      );
    }
  }

  static bool _isActiveOn(
    CourseModel course,
    DateTime date,
    DateTime semesterStart,
  ) {
    // Basic date range check if we had start/end dates for each course
    // But CourseModel only has startDate/endDate as timestamps (int)
    final start = DateTime.fromMillisecondsSinceEpoch(course.startDate);
    final end = DateTime.fromMillisecondsSinceEpoch(course.endDate);

    // We only care about date part for start/end comparisons roughly
    // Using difference in days logic or direct modification
    if (date.isBefore(start.subtract(const Duration(days: 1))) ||
        date.isAfter(end.add(const Duration(days: 1))))
      return false;

    // Check phase (legacy concept, but implicit in fromWeek/toWeek check relative to semester)
    // Here we replicate the simple check: does this week fall roughly within the from/to week range?

    // Calculate week number relative to semester start
    // Assuming semesterStart is Monday of week 1
    final diff = date.difference(semesterStart).inDays;
    final currentWeek = (diff / 7).floor() + 1;

    // Check if current week is within [fromWeek, toWeek]
    if (currentWeek >= course.fromWeek && currentWeek <= course.toWeek) {
      return true;
    }

    return false;
  }

  static Future<void> scheduleExamNotifications({
    required List<Legacy.StudentExamRoom> examRooms,
  }) async {
    for (final examRoom in examRooms) {
      final examDetail = examRoom.examRoom;
      if (examDetail == null) {
        _log.log(
          'Exam room ${examRoom.id} has no examRoom detail',
          level: LogLevel.warning,
        );
        continue;
      }

      final examDate = examDetail.examDate;
      final examHour = examDetail.examHour;

      if (examDate == null || examHour == null) {
        _log.log(
          'Exam ${examRoom.subjectName}: missing date or hour',
          level: LogLevel.warning,
        );
        continue;
      }

      final date = DateTime.fromMillisecondsSinceEpoch(examDate);

      final startString = examHour.startString;

      final startParts = startString.split(':');
      if (startParts.length != 2) {
        _log.log(
          'Invalid start time format: $startString',
          level: LogLevel.warning,
        );
        continue;
      }

      final hour = int.tryParse(startParts[0]);
      final minute = int.tryParse(startParts[1]);
      if (hour == null || minute == null) {
        _log.log(
          'Could not parse hour/minute from: $startString',
          level: LogLevel.warning,
        );
        continue;
      }

      final examDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      final now = DateTime.now();
      if (examDateTime.year > now.year + 10 || examDateTime.year < 2020) {
        _log.log(
          'Invalid exam date year: ${examDateTime.year} - SKIPPING',
          level: LogLevel.warning,
        );
        continue;
      }

      await _notificationService.scheduleExamNotifications(
        examRoom,
        examDateTime,
      );
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  static Future<int> getPendingNotificationCount() async {
    final pending = await _notificationService.getPendingNotifications();
    return pending.length;
  }
}
