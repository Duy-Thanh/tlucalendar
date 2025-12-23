import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tlucalendar/services/log_service.dart';

/// Service for sending daily reminders about classes and exams
/// Platform-specific implementation:
/// - Android: Uses AlarmManager for exact timing (even when app is closed)
/// - iOS: Uses scheduled notifications (native iOS scheduling)
class DailyNotificationService {
  static const int _alarmId = 0; // Unique ID for the daily alarm (Android)
  static const int _iosNotificationId = 999; // ID for iOS daily notification
  static final _log = LogService();

  /// Initialize the service (platform-specific)
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      // Removed log
    } else if (Platform.isIOS) {
      // Removed log
    }
  }

  /// Schedule daily check at specific time (e.g., 7 AM every day)
  static Future<void> scheduleDailyCheck({int hour = 7, int minute = 0}) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      // If time already passed today, schedule for tomorrow
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Removed log
    // Removed log
    // Removed log

    if (Platform.isAndroid) {
      // Android: Use AlarmManager for exact timing
      await AndroidAlarmManager.periodic(
        const Duration(days: 1), // Repeat every day
        _alarmId,
        _performDailyCheck,
        startAt: scheduledDate,
        exact: true, // Use exact alarm for precise timing
        wakeup: true, // Wake up device if sleeping
        rescheduleOnReboot: true, // Reschedule after device reboot
      );
      // Removed log
    } else if (Platform.isIOS) {
      // iOS: Use scheduled notifications with daily repeat
      await _scheduleIOSDailyNotification(hour: hour, minute: minute);
      // Removed log
    }

    // Removed log
  }

  /// Cancel daily check
  static Future<void> cancelDailyCheck() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.cancel(_alarmId);
      _log.log(
        'Android: Daily notification check cancelled',
        level: LogLevel.warning,
      );
    } else if (Platform.isIOS) {
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      await notificationsPlugin.cancel(_iosNotificationId);
      _log.log(
        'iOS: Daily notification check cancelled',
        level: LogLevel.warning,
      );
    }
  }

  /// Manually trigger daily check (for testing)
  static Future<void> triggerManualCheck() async {
    // Removed log
    await _performDailyCheck();
  }

  /// Schedule iOS daily notification using native scheduled notifications
  static Future<void> _scheduleIOSDailyNotification({
    int hour = 7,
    int minute = 0,
  }) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    // iOS initialization with proper settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(iOS: iosSettings);

    await notificationsPlugin.initialize(initSettings);

    // Schedule daily notification
    await notificationsPlugin.zonedSchedule(
      _iosNotificationId,
      '📅 Lịch học hôm nay',
      'Nhấn để xem lịch học và thi hôm nay',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeat daily at same time
    );

    // Removed log
  }

  /// Helper to get next instance of a specific time
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Check if there's a daily task scheduled
  static Future<bool> isDailyCheckScheduled() async {
    // AlarmManager doesn't provide a direct way to check
    // We'll rely on SharedPreferences in the actual implementation
    return true; // Placeholder
  }
}

/// Perform the daily schedule check
/// ⚠️ MUST be a top-level function for AlarmManager
@pragma('vm:entry-point')
Future<void> _performDailyCheck() async {
  final log = LogService();

  // Initialize notification plugin
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  // Get today's date
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  // Open database (sqlite3 FFI)
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = join(docsDir.path, 'tlu_calendar.db');

  // Ensure we can open it
  final database = sqlite3.open(dbPath, mode: OpenMode.readOnly);

  // Check for classes today
  // Convert Dart's weekday (1=Monday, 7=Sunday) to API format (2=Monday, 8=Sunday)
  final apiDayOfWeek = today.weekday == 7 ? 8 : today.weekday + 1;

  // Get current semester ID
  final currentSemesterResult = database.select('''
    SELECT id FROM semesters WHERE isCurrent = 1 LIMIT 1
  ''');

  final int? currentSemesterId = currentSemesterResult.isNotEmpty
      ? currentSemesterResult.first['id'] as int?
      : null;

  if (currentSemesterId == null) {
    log.log('[Background] No current semester found', level: LogLevel.warning);
    database.dispose();
    return;
  }

  final classes = database.select(
    '''
    SELECT DISTINCT 
      sc.courseName, 
      ch_start.startString, 
      ch_end.endString
    FROM student_courses sc
    JOIN course_hours ch_start ON sc.startCourseHour = ch_start.id
    JOIN course_hours ch_end ON sc.endCourseHour = ch_end.id
    WHERE sc.semesterId = ?
      AND sc.dayOfWeek = ?
      AND sc.fromWeek <= ?
      AND sc.toWeek >= ?
    ORDER BY ch_start.startString
  ''',
    [
      currentSemesterId, // Only current semester
      apiDayOfWeek, // Use API format: 2=Mon, 3=Tue, ..., 8=Sun
      _getCurrentWeekNumber(today),
      _getCurrentWeekNumber(today),
    ],
  );

  // Check for exams today
  final exams = database.select(
    '''
    SELECT DISTINCT subjectName, examDateString, roomCode
    FROM exam_rooms
    WHERE semesterId = ?
      AND examDate >= ?
      AND examDate < ?
    ORDER BY examDate
  ''',
    [
      currentSemesterId, // Only current semester
      todayStart.millisecondsSinceEpoch,
      todayEnd.millisecondsSinceEpoch,
    ],
  );

  database.dispose();

  // Filter out past classes (only show upcoming ones)
  final currentTime = today;
  // Convert ResultSet to list of maps for ease of use
  final classList = classes
      .map(
        (r) => {
          'courseName': r['courseName'],
          'startString': r['startString'],
          'endString': r['endString'],
        },
      )
      .toList();

  final upcomingClasses = classList.where((cls) {
    try {
      final startTime = cls['startString'] as String;
      final parts = startTime.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final classDateTime = DateTime(
          today.year,
          today.month,
          today.day,
          hour,
          minute,
        );

        // Keep class if it starts in the future (or within 15 minutes - already started but not too late)
        return classDateTime.isAfter(
          currentTime.subtract(const Duration(minutes: 15)),
        );
      }
      return true; // Keep if can't parse time
    } catch (e) {
      return true; // Keep if error parsing
    }
  }).toList();

  // Convert exams ResultSet to list of maps
  final examList = exams
      .map(
        (r) => {
          'subjectName': r['subjectName'],
          'examDateString': r['examDateString'],
          'roomCode': r['roomCode'],
        },
      )
      .toList();

  final upcomingExams =
      examList; // Exams are usually all-day events, keep all for today

  // Send notification if there's anything scheduled
  if (upcomingClasses.isNotEmpty || upcomingExams.isNotEmpty) {
    await _sendDailySummaryNotification(
      notificationsPlugin,
      upcomingClasses,
      upcomingExams,
    );
  }
}

/// Send daily summary notification
Future<void> _sendDailySummaryNotification(
  FlutterLocalNotificationsPlugin plugin,
  List<Map<String, dynamic>> classes,
  List<Map<String, dynamic>> exams,
) async {
  final today = DateTime.now();
  final dateStr = '${today.day}/${today.month}/${today.year}';

  // Build notification content
  String title;
  String body;

  if (classes.isNotEmpty && exams.isNotEmpty) {
    title = '📅 Lịch hôm nay ($dateStr)';
    body = '${classes.length} lớp học và ${exams.length} kỳ thi';
  } else if (classes.isNotEmpty) {
    title = '📚 Lịch học hôm nay ($dateStr)';
    final firstClass = classes.first;
    body = classes.length == 1
        ? 'Tiết ${firstClass['startString']}: ${firstClass['courseName']}'
        : '${classes.length} lớp học - Bắt đầu từ tiết ${classes.first['startString']}';
  } else {
    title = '📝 Lịch thi hôm nay ($dateStr)';
    final firstExam = exams.first;
    body = exams.length == 1
        ? '${firstExam['subjectName']} - Phòng ${firstExam['roomCode']}'
        : '${exams.length} kỳ thi';
  }

  // Build big text style for expanded notification
  final bigText = StringBuffer();

  if (classes.isNotEmpty) {
    bigText.writeln('📚 Lớp học:');
    for (var i = 0; i < classes.length && i < 5; i++) {
      final cls = classes[i];
      bigText.writeln(
        '  • Tiết ${cls['startString']}-${cls['endString']}: ${cls['courseName']}',
      );
    }
    if (classes.length > 5) {
      bigText.writeln('  ... và ${classes.length - 5} lớp khác');
    }
  }

  if (exams.isNotEmpty) {
    if (bigText.isNotEmpty) bigText.writeln();
    bigText.writeln('📝 Lịch thi:');
    for (var i = 0; i < exams.length && i < 3; i++) {
      final exam = exams[i];
      bigText.writeln('  • ${exam['subjectName']} - Phòng ${exam['roomCode']}');
    }
    if (exams.length > 3) {
      bigText.writeln('  ... và ${exams.length - 3} kỳ thi khác');
    }
  }

  // Send notification with big text style
  final androidDetailsWithBigText = AndroidNotificationDetails(
    'daily_summary',
    'Thông báo hàng ngày',
    channelDescription: 'Nhắc nhở lịch học và thi mỗi ngày',
    importance: Importance.high,
    priority: Priority.high,
    styleInformation: BigTextStyleInformation(bigText.toString()),
  );

  final notificationDetailsWithBigText = NotificationDetails(
    android: androidDetailsWithBigText,
  );

  await plugin.show(
    99999, // Unique ID for daily summary
    title,
    body,
    notificationDetailsWithBigText,
  );

  final log = LogService();
  // Removed log
}

/// Calculate current week number
int _getCurrentWeekNumber(DateTime date) {
  // This is a simplified version - adjust based on your semester structure
  // Assuming semester starts in September
  final semesterStart = DateTime(date.year, 9, 1);
  if (date.isBefore(semesterStart)) {
    // Previous semester (started in February)
    final prevSemesterStart = DateTime(date.year, 2, 1);
    final difference = date.difference(prevSemesterStart);
    return (difference.inDays / 7).floor() + 1;
  } else {
    final difference = date.difference(semesterStart);
    return (difference.inDays / 7).floor() + 1;
  }
}
