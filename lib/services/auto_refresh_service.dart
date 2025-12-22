import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/core/parser/json_parser.dart';
import 'package:tlucalendar/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_remote_data_source.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_remote_data_source.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_local_data_source.dart';

class AutoRefreshService {
  static const int _alarmId = 1; // Unique ID for auto-refresh
  static final _log = LogService();

  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      // Schedule periodic refresh every 6 hours
      // We rely on credentials being saved
      await schedulePeriodicRefresh();
    }
  }

  static Future<void> schedulePeriodicRefresh() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.periodic(
        const Duration(hours: 6),
        _alarmId,
        _performAutoRefresh,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      _log.log('Auto-refresh scheduled every 6 hours');
    }
  }

  // Public method to trigger refresh manually (e.g., after login)
  static Future<void> triggerRefresh() async {
    await _performAutoRefresh();
  }

  // Background task
  @pragma('vm:entry-point')
  static Future<void> _performAutoRefresh() async {
    final log = LogService();
    log.log('[Background] Starting Auto-Refresh...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final studentCode = prefs.getString('userStudentCode');
      final password = prefs.getString('userPassword');

      if (studentCode == null || password == null) {
        log.log('[Background] No credentials found. Aborting.');
        return;
      }

      // 1. Login
      final networkClient = NetworkClient(
        baseUrl: 'https://sinhvien1.tlu.edu.vn/education',
      );
      final jsonParser = DartJsonParser();
      final authRemote = AuthRemoteDataSourceImpl(
        client: networkClient,
        jsonParser: jsonParser,
      );

      final tokenMap = await authRemote.login(studentCode, password);
      final accessToken = tokenMap['access_token'];

      if (accessToken == null) {
        log.log('[Background] Login failed (no token).');
        return;
      }

      // Save new token
      await prefs.setString('accessToken', accessToken);

      // 2. Fetch Data
      final scheduleRemote = ScheduleRemoteDataSourceImpl(
        client: networkClient,
        jsonParser: jsonParser,
      );
      final dbHelper = DatabaseHelper.instance;

      // Fetch School Years & Semesters
      final years = await scheduleRemote.getSchoolYears(accessToken);
      // Map SchoolYear -> SchoolYearModel if needed, but getSchoolYears returns Models in DataSource layer usually?
      // Wait, DataSource returns Models. Repository returns Entities.
      // ScheduleRemoteDataSourceImpl returns List<SchoolYearModel>. Correct.

      await dbHelper.saveSchoolYears(years);

      // Save flattened semesters
      final allSemesters = years.expand((y) => y.semesters).map((s) {
        if (s is SemesterModel) return s;
        return SemesterModel(
          id: s.id,
          semesterCode: s.semesterCode,
          semesterName: s.semesterName,
          startDate: s.startDate,
          endDate: s.endDate,
          isCurrent: s.isCurrent,
          ordinalNumbers: s.ordinalNumbers,
        );
      }).toList();
      await dbHelper.saveSemesters(allSemesters);

      // Get Current Semester
      final currentSem = allSemesters.firstWhere(
        (s) => s.isCurrent,
        orElse: () => allSemesters.last,
      );

      // Fetch Courses
      final courses = await scheduleRemote.getCourses(
        currentSem.id,
        accessToken,
      );
      await dbHelper.saveCourses(currentSem.id, courses);

      // Fetch Course Hours
      try {
        final hours = await scheduleRemote.getCourseHours(accessToken);
        // Convert List to Map for DB
        final hourMap = {for (var h in hours) h.id: h};
        await dbHelper.saveCourseHours(hourMap);
      } catch (e) {
        log.log(
          '[Background] Failed to fetch course hours: $e',
          level: LogLevel.warning,
        );
      }

      // 3. Fetch Exam Data
      // For exams we need raw token data for cookies.
      // Ideally we should parse the raw token from prefs if we stored it...
      // But for now, we try with accessToken.
      // If ExamRemoteDataSource needs rawToken, we might need to store it in prefs during login.
      // In AuthProvider we stored it: await _prefs.setString('rawToken', jsonEncode(tokenData));

      final rawTokenStr = prefs.getString('rawToken');
      Map<String, dynamic>? rawToken;
      if (rawTokenStr != null) {
        try {
          final parsed = jsonParser.parse(rawTokenStr);
          if (parsed is Map<String, dynamic>) {
            rawToken = parsed;
          }
        } catch (_) {}
      }

      final examRemote = ExamRemoteDataSourceImpl(
        client: networkClient,
        jsonParser: jsonParser,
      );
      final examLocal = ExamLocalDataSourceImpl(databaseHelper: dbHelper);

      try {
        // Fetch Exam Schedules (Register Periods) for current semester
        final examSchedules = await examRemote.getExamSchedules(
          currentSem.id,
          accessToken,
          rawToken,
        );

        await examLocal.cacheExamSchedules(currentSem.id, examSchedules);

        // Ensure "Lần 1" (Round 1) is cached at least, maybe Round 2 too?
        // Let's try to fetch exams for each schedule if available.
        for (var schedule in examSchedules) {
          // Fetch Round 1
          try {
            final rooms1 = await examRemote.getExamRooms(
              semesterId: currentSem.id,
              scheduleId: schedule.id,
              round: 1,
              accessToken: accessToken,
              rawToken: rawToken,
            );
            await examLocal.cacheExamRooms(
              semesterId: currentSem.id,
              scheduleId: schedule.id,
              round: 1,
              rooms: rooms1,
            );
          } catch (_) {}

          // Fetch Round 2 (just in case)
          try {
            final rooms2 = await examRemote.getExamRooms(
              semesterId: currentSem.id,
              scheduleId: schedule.id,
              round: 2,
              accessToken: accessToken,
              rawToken: rawToken,
            );
            await examLocal.cacheExamRooms(
              semesterId: currentSem.id,
              scheduleId: schedule.id,
              round: 2,
              rooms: rooms2,
            );
          } catch (_) {}
        }
      } catch (e) {
        log.log(
          '[Background] Failed to fetch exam data: $e',
          level: LogLevel.warning,
        );
      }

      log.log('[Background] Auto-Refresh Complete. Data updated.');

      // We could trigger a notification here to say "Schedule Updated" if things changed,
      // but let's keep it silent for now unless requested.
    } catch (e) {
      log.log('[Background] Auto-Refresh Failed: $e', level: LogLevel.error);
    }
  }
}
