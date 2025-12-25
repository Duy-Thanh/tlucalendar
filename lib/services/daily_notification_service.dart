import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tlucalendar/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for sending daily reminders about classes and exams
/// Platform-specific implementation:
/// - Android: Uses AlarmManager for exact timing (Rescheduling OneShot)
/// - iOS: Uses scheduled notifications (native iOS scheduling)
class DailyNotificationService {
  static const int _alarmId = 0; // Unique ID for the daily alarm (Android)
  static const int _iosNotificationId = 999; // ID for iOS daily notification
  static final _log = LogService();

  /// Initialize the service (platform-specific)
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      await _createNotificationChannel();
    }
  }

  /// Request necessary permissions (Notification & Exact Alarm)
  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } else if (Platform.isIOS) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    }
  }

  /// Create the notification channel explicitly
  static Future<void> _createNotificationChannel() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      const channel = AndroidNotificationChannel(
        'daily_summary', // id
        'Thông báo hàng ngày', // title
        description: 'Nhắc nhở lịch học và thi mỗi ngày',
        importance: Importance.high,
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(channel);
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

    if (Platform.isAndroid) {
      // Android: Use OneShot + Reschedule for reliable exact timing
      await AndroidAlarmManager.cancel(
        _alarmId,
      ); // Cancel previous just in case
      await AndroidAlarmManager.oneShotAt(
        scheduledDate,
        _alarmId,
        _performDailyCheck,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      _log.log('Android: Daily check scheduled at $scheduledDate (OneShot)');
    } else if (Platform.isIOS) {
      // iOS: Use scheduled notifications with daily repeat
      await _scheduleIOSDailyNotification(hour: hour, minute: minute);
    }
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
}

/// Perform the daily schedule check
/// ⚠️ MUST be a top-level function for AlarmManager
@pragma('vm:entry-point')
Future<void> _performDailyCheck() async {
  final log = LogService();

  // 1. Reschedule next alarm immediately (to ensure chain continues)
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('setting_daily_notif') ?? true;

    if (enabled) {
      final hour = prefs.getInt('setting_daily_notif_hour') ?? 7;
      final minute = prefs.getInt('setting_daily_notif_minute') ?? 0;

      final now = DateTime.now();
      // Schedule for TOMORROW at specific time
      // Logic: This task runs AT the scheduled time (e.g. 7:00 today).
      // So we want to schedule for 7:00 tomorrow.
      var nextRun = DateTime(now.year, now.month, now.day, hour, minute);

      // If we are currently executing, it's likely around the target time.
      // Make sure we schedule for FUTURE (tomorrow).
      if (nextRun.isBefore(now.add(const Duration(minutes: 1)))) {
        nextRun = nextRun.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        nextRun,
        0, // _alarmId
        _performDailyCheck,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      log.log('[Background] Rescheduled daily check for $nextRun');
    } else {
      log.log('[Background] Daily check disabled, not rescheduling.');
    }
  } catch (e) {
    log.log(
      '[Background] Failed to reschedule daily check: $e',
      level: LogLevel.error,
    );
  }

  // 2. Perform actual check logic
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

  // Get current semester ID and Start Date
  final currentSemesterResult = database.select('''
    SELECT id, startDate FROM semesters WHERE isCurrent = 1 LIMIT 1
  ''');

  final int? currentSemesterId;
  final DateTime? semesterStartDate;

  if (currentSemesterResult.isNotEmpty) {
    currentSemesterId = currentSemesterResult.first['id'] as int;
    final startMillis = currentSemesterResult.first['startDate'] as int;
    semesterStartDate = DateTime.fromMillisecondsSinceEpoch(startMillis);
  } else {
    currentSemesterId = null;
    semesterStartDate = null;
  }

  if (currentSemesterId == null || semesterStartDate == null) {
    log.log('[Background] No current semester found', level: LogLevel.warning);
    database.dispose();
    return;
  }

  final currentWeek = _getCurrentWeekNumber(today, semesterStartDate);
  log.log(
    '[Background] Today: $today, SemesterStart: $semesterStartDate, Week: $currentWeek',
  );

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
      currentWeek,
      currentWeek,
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

  final upcomingClasses =
      classList; // Show all classes for the day, not just future ones
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
  log.log('Sent daily notification: $title');
}

/// Calculate current week number
int _getCurrentWeekNumber(DateTime date, DateTime semesterStart) {
  if (date.isBefore(semesterStart)) {
    // If date is BEFORE semester start, it likely belongs to previous semester?
    // Or it's break time.
    // If we assume standard logic:
    // Return negative or 0?
    // For now, let's just return 1 if close, or calculate backward.
    // However, our SQL query is `fromWeek <= ? AND toWeek >= ?`.
    // If we return 0, and course is 1-15, 0 <= 15 is true. But 1 <= 0 is false.
    // Classes usually start week 1.
    return 1;
  }

  // Calculate difference in days
  final difference = date.difference(semesterStart).inDays;
  return (difference / 7).floor() + 1;
}
