import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/notification_service.dart';
import 'package:tlucalendar/services/log_service.dart';

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();
  static final _log = LogService();

  /// Schedule notifications for all classes in the current week
  static Future<void> scheduleWeekClassNotifications({
    required List<StudentCourseSubject> courses,
    required Map<int, CourseHour> courseHours,
    required DateTime weekStartDate,
    required DateTime semesterStartDate,
  }) async {
// Removed log
// Removed log
// Removed log
// Removed log
    
    final now = DateTime.now();

    for (final course in courses) {
      // Check if course is active during this week
      if (!course.isActiveOn(weekStartDate, semesterStartDate)) {
// Removed log
        continue;
      }

// Removed log
      
      // Get day of week from API (2=Monday, 3=Tuesday, ..., 8=Sunday)
      // Convert to 0-based (0=Monday, 1=Tuesday, ..., 6=Sunday)
      final apiDayOfWeek = course.dayOfWeek;
      final dayOfWeek = apiDayOfWeek - 2; // Convert from 2-based to 0-based
// Removed log
// Removed log

      // Calculate the actual date for this class in the week
      final classDate = weekStartDate.add(Duration(days: dayOfWeek));
// Removed log
// Removed log
// Removed log
// Removed log

      // Skip if class date is in the past
      if (classDate.isBefore(now) && !_isSameDay(classDate, now)) {
// Removed log
        continue;
      }

      // Get start hour details
      final startCourseHour = courseHours[course.startCourseHour];
      if (startCourseHour == null) {
        _log.log('No start course hour found for ID: ${course.startCourseHour}', level: LogLevel.warning);
        continue;
      }

      // Get end hour details  
      final endCourseHour = courseHours[course.endCourseHour];
      if (endCourseHour == null) {
        _log.log('No end course hour found for ID: ${course.endCourseHour}', level: LogLevel.warning);
        continue;
      }

      // Parse start time from startString (e.g., "07:00")
      final startParts = startCourseHour.startString.split(':');
      if (startParts.length != 2) {
        _log.log('Invalid start time format: ${startCourseHour.startString}', level: LogLevel.warning);
        continue;
      }

      final hour = int.tryParse(startParts[0]);
      final minute = int.tryParse(startParts[1]);
      if (hour == null || minute == null) {
        _log.log('Could not parse hour/minute from: ${startCourseHour.startString}', level: LogLevel.warning);
        continue;
      }

      // Create the full datetime for the class
      final classDateTime = DateTime(
        classDate.year,
        classDate.month,
        classDate.day,
        hour,
        minute,
      );
      
      // Validate year to prevent 32099 bug
      if (classDateTime.year > now.year + 10 || classDateTime.year < 2020) {
        _log.log('Invalid class date year: ${classDateTime.year} - SKIPPING', level: LogLevel.warning);
        continue;
      }

      // Format time slot string using the string fields
      final timeSlot = '${startCourseHour.startString} - ${endCourseHour.endString}';

      // Schedule notifications
      await _notificationService.scheduleClassNotifications(
        course,
        classDateTime,
        dayOfWeek + 2, // Convert to 2-based (2=Monday, 3=Tuesday, etc.)
        timeSlot,
      );
    }
  }

  /// Schedule notifications for upcoming exams
  static Future<void> scheduleExamNotifications({
    required List<StudentExamRoom> examRooms,
  }) async {
// Removed log
    
    for (final examRoom in examRooms) {
      final examDetail = examRoom.examRoom;
      if (examDetail == null) {
        _log.log('Exam room ${examRoom.id} has no examRoom detail', level: LogLevel.warning);
        continue;
      }

      // Get exam date and time
      final examDate = examDetail.examDate;
      final examHour = examDetail.examHour;

      if (examDate == null || examHour == null) {
        _log.log('Exam ${examRoom.subjectName}: missing date or hour', level: LogLevel.warning);
        continue;
      }

      // Convert timestamp to DateTime
      final date = DateTime.fromMillisecondsSinceEpoch(examDate);
// Removed log
// Removed log

      // Parse exam hour start time from startString (e.g., "07:00")
      final startString = examHour.startString;
      if (startString == null) {
        _log.log('No startString in examHour', level: LogLevel.warning);
        continue;
      }
      
// Removed log

      final startParts = startString.split(':');
      if (startParts.length != 2) {
        _log.log('Invalid start time format: $startString', level: LogLevel.warning);
        continue;
      }

      final hour = int.tryParse(startParts[0]);
      final minute = int.tryParse(startParts[1]);
      if (hour == null || minute == null) {
        _log.log('Could not parse hour/minute from: $startString', level: LogLevel.warning);
        continue;
      }

      // Create full exam datetime
      final examDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      
// Removed log
// Removed log
// Removed log
      
      // Validate year to prevent invalid dates
      final now = DateTime.now();
      if (examDateTime.year > now.year + 10 || examDateTime.year < 2020) {
        _log.log('Invalid exam date year: ${examDateTime.year} - SKIPPING', level: LogLevel.warning);
        continue;
      }

      // Schedule notifications
      await _notificationService.scheduleExamNotifications(
        examRoom,
        examDateTime,
      );
    }
  }

  /// Check if two dates are the same day
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  /// Get count of pending notifications
  static Future<int> getPendingNotificationCount() async {
    final pending = await _notificationService.getPendingNotifications();
    return pending.length;
  }
}
