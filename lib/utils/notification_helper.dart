import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/notification_service.dart';

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();

  /// Schedule notifications for all classes in the current week
  static Future<void> scheduleWeekClassNotifications({
    required List<StudentCourseSubject> courses,
    required Map<int, CourseHour> courseHours,
    required DateTime weekStartDate,
    required DateTime semesterStartDate,
  }) async {
    print('🔔 scheduleWeekClassNotifications called');
    print('   Courses: ${courses.length}');
    print('   Week start: $weekStartDate');
    print('   Semester start: $semesterStartDate');
    
    final now = DateTime.now();

    for (final course in courses) {
      // Check if course is active during this week
      if (!course.isActiveOn(weekStartDate, semesterStartDate)) {
        print('   ⏭️ Course ${course.courseName} not active this week');
        continue;
      }

      print('   ✅ Course ${course.courseName} is active');
      
      // Get day of week (0=Monday, 1=Tuesday, ..., 6=Sunday)
      final dayOfWeek = course.dayOfWeek;
      print('      Day of week: $dayOfWeek (0=Mon, 6=Sun)');

      // Calculate the actual date for this class in the week
      final classDate = weekStartDate.add(Duration(days: dayOfWeek));
      print('      Class date: $classDate');

      // Skip if class date is in the past
      if (classDate.isBefore(now) && !_isSameDay(classDate, now)) {
        print('      ⏭️ Class date is in the past');
        continue;
      }

      // Get start hour details
      final startCourseHour = courseHours[course.startCourseHour];
      if (startCourseHour == null) {
        print('      ⚠️ No start course hour found for ID: ${course.startCourseHour}');
        continue;
      }

      // Get end hour details  
      final endCourseHour = courseHours[course.endCourseHour];
      if (endCourseHour == null) {
        print('      ⚠️ No end course hour found for ID: ${course.endCourseHour}');
        continue;
      }

      // Parse start time
      final hour = startCourseHour.start ~/ 100; // 700 -> 7
      final minute = startCourseHour.start % 100; // 700 -> 0
      print('      Start time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');

      // Create the full datetime for the class
      final classDateTime = DateTime(
        classDate.year,
        classDate.month,
        classDate.day,
        hour,
        minute,
      );
      
      print('      Class DateTime: $classDateTime');
      print('      Current time: $now');
      print('      Is in future: ${classDateTime.isAfter(now)}');

      // Format time slot string
      final timeSlot = '${_formatTime(startCourseHour.start)} - ${_formatTime(endCourseHour.end)}';

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
    print('🔔 scheduleExamNotifications called with ${examRooms.length} exam rooms');
    
    for (final examRoom in examRooms) {
      final examDetail = examRoom.examRoom;
      if (examDetail == null) {
        print('   ⚠️ Exam room ${examRoom.id} has no examRoom detail');
        continue;
      }

      // Get exam date and time
      final examDate = examDetail.examDate;
      final examHour = examDetail.examHour;

      if (examDate == null || examHour == null) {
        print('   ⚠️ Exam ${examRoom.subjectName}: missing date or hour');
        continue;
      }

      // Convert timestamp to DateTime
      final date = DateTime.fromMillisecondsSinceEpoch(examDate);
      print('   📅 Exam: ${examRoom.subjectName}');
      print('      Date from timestamp: $date');

      // Parse exam hour start time from startString (e.g., "07:00")
      final startString = examHour.startString;
      if (startString == null) {
        print('      ⚠️ No startString in examHour');
        continue;
      }
      
      print('      Start time string: $startString');

      final startParts = startString.split(':');
      if (startParts.length != 2) {
        print('      ⚠️ Invalid start time format: $startString');
        continue;
      }

      final hour = int.tryParse(startParts[0]);
      final minute = int.tryParse(startParts[1]);
      if (hour == null || minute == null) {
        print('      ⚠️ Could not parse hour/minute from: $startString');
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
      
      print('      📍 Exam DateTime: $examDateTime');
      print('      📍 Current time: ${DateTime.now()}');
      print('      📍 Is in future: ${examDateTime.isAfter(DateTime.now())}');

      // Schedule notifications
      await _notificationService.scheduleExamNotifications(
        examRoom,
        examDateTime,
      );
    }
  }

  /// Format time from int (700) to string ("07:00")
  static String _formatTime(int time) {
    final hour = time ~/ 100;
    final minute = time % 100;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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
