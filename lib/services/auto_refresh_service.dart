import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/core/network/network_client.dart';

import 'package:tlucalendar/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_remote_data_source.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_remote_data_source.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_local_data_source.dart';

@pragma('vm:entry-point')
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
  static Future<void> triggerRefresh({
    String? accessToken,
    String? rawToken,
  }) async {
    if (accessToken != null) {
      // If we have a token (from Login), use it directly to save time
      await _syncData(accessToken, rawToken: rawToken, isForeground: true);
    } else {
      // Otherwise perform full cycle (Login + Sync)
      await _performAutoRefresh();
    }
  }

  // Cancel periodic refresh
  static Future<void> cancelPeriodicRefresh() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.cancel(_alarmId);
      final log = LogService();
      log.log('Auto-refresh cancelled');
    }
  }

  // Shared Sync Logic
  static Future<void> _syncData(
    String accessToken, {
    String? rawToken,
    bool isForeground = false,
  }) async {
    final log = LogService();
    log.log('[Sync] Starting Data Sync (Foreground: $isForeground)...');

    final networkClient = NetworkClient(
      baseUrl: 'https://tlu-proxy-node.vercel.app',
    );
    final scheduleRemote = ScheduleRemoteDataSourceImpl(client: networkClient);
    final dbHelper = DatabaseHelper.instance;

    try {
      // --- PHASE 1: ESSENTIALS (Blocking if Foreground) ---
      // School Years, Semesters, Courses, Course Hours

      final years = await scheduleRemote.getSchoolYears(accessToken);
      await dbHelper.saveSchoolYears(years);

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

      if (allSemesters.isEmpty) {
        log.log('[Sync] No semesters found. Aborting.');
        return;
      }

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
        final hourMap = {for (var h in hours) h.id: h};
        await dbHelper.saveCourseHours(hourMap);
      } catch (e) {
        log.log(
          '[Sync] Failed to fetch course hours: $e',
          level: LogLevel.warning,
        );
      }

      log.log('[Sync] Essentials synced.');

      // --- PHASE 2: EXAMS (Non-Blocking if Foreground) ---

      Future<void> syncExams() async {
        try {
          final examRemote = ExamRemoteDataSourceImpl(client: networkClient);
          final examLocal = ExamLocalDataSourceImpl(databaseHelper: dbHelper);

          final examSchedules = await examRemote.getExamSchedules(
            currentSem.id,
            accessToken,
            rawToken,
          );
          await examLocal.cacheExamSchedules(currentSem.id, examSchedules);

          for (var schedule in examSchedules) {
            // Round 1
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

            // Round 2
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
          log.log('[Sync] Exams synced.');
        } catch (e) {
          log.log(
            '[Sync] Failed to fetch exam data: $e',
            level: LogLevel.warning,
          );
        }
      }

      if (isForeground) {
        // Fire and forget for exams
        syncExams();
      } else {
        // Background mode (AlarmManager) must await everything
        await syncExams();
      }
    } catch (e) {
      log.log('[Sync] Error: $e', level: LogLevel.error);
      rethrow;
    }
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

      // 1. Login with Retry Logic (Max 3 attempts)
      final networkClient = NetworkClient(
        baseUrl: 'https://tlu-proxy-node.vercel.app',
      );
      final authRemote = AuthRemoteDataSourceImpl(client: networkClient);

      String? accessToken;

      for (int i = 0; i < 3; i++) {
        try {
          final tokenMap = await authRemote.login(studentCode, password);
          accessToken = tokenMap['access_token'];
          if (accessToken != null) break; // Success
        } catch (e) {
          log.log('[Background] Login attempt ${i + 1} failed: $e');
          if (i < 2) await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (accessToken == null) {
        log.log('[Background] Login failed after 3 attempts. Aborting.');
        return;
      }

      // Save new token
      await prefs.setString('accessToken', accessToken);
      // Try to get rawToken if available, implicitly handled by login response usually but here we just get access_token
      // We can assume rawToken is same as tokenMap json if needed, or null if we don't parse it here.
      // For background refresh, we might usually fail to get raw specific fields if not careful,
      // but let's pass tokenMap json string if possible.
      // However, authRemote.login returns Map.

      // 2. Sync
      await _syncData(
        accessToken,
        isForeground: false,
      ); // Background must await all

      log.log('[Background] Auto-Refresh Complete.');
    } catch (e) {
      log.log('[Background] Auto-Refresh Failed: $e', level: LogLevel.error);
    }
  }
}
