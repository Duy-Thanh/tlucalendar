import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/exam/data/models/exam_dtos.dart' as Legacy;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _log = LogService();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _requestPermissions();

    _initialized = true;
  }

  Future<bool> _requestPermissions() async {
    bool granted = false;

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final result = await androidPlugin.requestNotificationsPermission();
      granted = result ?? false;
    }

    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      final result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = result ?? false;
    }

    return granted;
  }

  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final result = await androidPlugin.areNotificationsEnabled();
      return result ?? false;
    }
    return _initialized;
  }

  Future<bool> requestPermissions() async {
    return await _requestPermissions();
  }

  void _onNotificationTapped(NotificationResponse response) {}

  Future<void> scheduleClassNotifications(
    Course course,
    DateTime classDateTime,
    int weekDay,
    String timeSlot,
  ) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    if (classDateTime.isBefore(now)) return;

    final subjectName = course.courseName;
    final baseId =
        '${course.id}_${weekDay}_${classDateTime.millisecondsSinceEpoch}'
            .hashCode;

    final oneHourBefore = classDateTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 1,
        title: 'Sắp đến giờ học!',
        body: 'Còn 1 giờ nữa là đến giờ học môn: $subjectName!',
        scheduledDate: oneHourBefore,
        payload: 'class_${course.id}_1h',
      );
    }

    final thirtyMinBefore = classDateTime.subtract(const Duration(minutes: 30));
    if (thirtyMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 2,
        title: 'Sắp đến giờ học!',
        body: 'Còn 30 phút nữa là đến giờ học môn: $subjectName!',
        scheduledDate: thirtyMinBefore,
        payload: 'class_${course.id}_30m',
      );
    }

    final fifteenMinBefore = classDateTime.subtract(
      const Duration(minutes: 15),
    );
    if (fifteenMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 3,
        title: 'Sắp đến giờ học!',
        body: 'Còn 15 phút nữa là đến giờ học môn: $subjectName!',
        scheduledDate: fifteenMinBefore,
        payload: 'class_${course.id}_15m',
      );
    }
  }

  // Optimized method for Native C++ Notifications
  Future<void> scheduleNativeClassNotification(
    // We use dynamic or import the model, but usually better to import.
    // For now, let's pass fields or use the model if imports allow.
    // Since NotificationService is low level, we might not want to import NativeParser types if it causes cycles?
    // NativeParser is in core, NotificationService in services. Core -> Services? No.
    // usually Services -> Core. So we can import NativeParser.
    dynamic
    model, // using dynamic to avoid import duplication issues if any, or just fields
  ) async {
    if (!_initialized) await initialize();

    final classDateTime = DateTime.fromMillisecondsSinceEpoch(
      model.triggerTime,
    );
    final now = DateTime.now();
    if (classDateTime.isBefore(now)) return;

    final subjectName =
        model.title; // Adjusted: Native model title has "Lịch học: " prefix?
    // C++: "Lịch học: %s"
    // Dart existing: "Sắp đến giờ học môn: $subjectName"
    // We should probably just pass the raw Subject Name from C++ if we want to match exact text?
    // Or just use the C++ title as is.
    // C++ Body: "Phòng: %s | Giờ: %s"

    // Let's use the C++ provided Title/Body directly for the notification content?
    // But the current logic adds "Còn 1 giờ nữa...".
    // If we want exact parity, C++ should return just the data.
    // But C++ returned formatted strings.
    // Let's just use the C++ title/body for the notification "Body" or "Title".

    // Current Native Impl:
    // Title: "Lịch học: Data Structures"
    // Body: "Phòng: B1 | Giờ: 07:00"

    // Desired Notification:
    // Title: "Sắp đến giờ học!"
    // Body: "Còn ... môn Data Structures"

    // Since C++ strings are already formatted, we might just use them.
    // "Lịch học: Data Structures" is a good Title.
    // Body: "Phòng: B1... (Còn 1h)"

    // Let's stick to the C++ strings for simplicity and speed.
    // We can append " - Còn 1h" to the body.

    final baseId = model.id;

    final oneHourBefore = classDateTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 1,
        title: model.title,
        body: '${model.body} (Còn 1 giờ)',
        scheduledDate: oneHourBefore,
        payload: 'native_class_${model.id}',
      );
    }

    final thirtyMinBefore = classDateTime.subtract(const Duration(minutes: 30));
    if (thirtyMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 2,
        title: model.title,
        body: '${model.body} (Còn 30 phút)',
        scheduledDate: thirtyMinBefore,
        payload: 'native_class_${model.id}',
      );
    }

    final fifteenMinBefore = classDateTime.subtract(
      const Duration(minutes: 15),
    );
    if (fifteenMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 3,
        title: model.title,
        body: '${model.body} (Còn 15 phút)',
        scheduledDate: fifteenMinBefore,
        payload: 'native_class_${model.id}',
      );
    }
  }

  Future<void> scheduleExamNotifications(
    Legacy.StudentExamRoom examRoom,
    DateTime examDateTime,
  ) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    if (examDateTime.isBefore(now)) return;

    final subjectName = examRoom.subjectName;
    final examCode = examRoom.examCode ?? '';
    final baseId =
        '${examRoom.id}_${examDateTime.millisecondsSinceEpoch}'.hashCode;

    final oneHourBefore = examDateTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 1,
        title: 'Sắp đến giờ thi!',
        body:
            'Còn 1 giờ nữa là đến giờ thi môn: $subjectName${examCode.isNotEmpty ? ' ($examCode)' : ''}!',
        scheduledDate: oneHourBefore,
        payload: 'exam_${examRoom.id}_1h',
      );
    }

    final thirtyMinBefore = examDateTime.subtract(const Duration(minutes: 30));
    if (thirtyMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 2,
        title: 'Sắp đến giờ thi!',
        body:
            'Còn 30 phút nữa là đến giờ thi môn: $subjectName${examCode.isNotEmpty ? ' ($examCode)' : ''}!',
        scheduledDate: thirtyMinBefore,
        payload: 'exam_${examRoom.id}_30m',
      );
    }

    final fifteenMinBefore = examDateTime.subtract(const Duration(minutes: 15));
    if (fifteenMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: baseId + 3,
        title: 'Sắp đến giờ thi!',
        body:
            'Còn 15 phút nữa là đến giờ thi môn: $subjectName${examCode.isNotEmpty ? ' ($examCode)' : ''}!',
        scheduledDate: fifteenMinBefore,
        payload: 'exam_${examRoom.id}_15m',
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final now = DateTime.now();
    final maxYear = now.year + 10;

    if (scheduledDate.year > maxYear || scheduledDate.year < 2020) {
      _log.log(
        'Invalid scheduled date: $scheduledDate',
        level: LogLevel.warning,
      );
      return;
    }

    if (scheduledDate.isBefore(now)) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'class_exam_reminders',
      'Nhắc nhở lịch học và lịch thi',
      channelDescription: 'Thông báo nhắc nhở trước giờ học và giờ thi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'class_exam_reminders',
      'Nhắc nhở lịch học và lịch thi',
      channelDescription: 'Thông báo nhắc nhở trước giờ học và giờ thi',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }
}
