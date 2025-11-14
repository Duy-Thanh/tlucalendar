import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:tlucalendar/services/auth_service.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/models/api_response.dart';

/// Service for automatic daily data refresh
/// Schedules silent background updates at random times (8 AM - 12 PM) to avoid DDOS
class AutoRefreshService {
  static const int _alarmId = 100; // Unique ID for auto-refresh alarm
  static const _storage = FlutterSecureStorage();
  static final _log = LogService();
  
  // Secure storage keys
  static const String _studentCodeKey = 'secure_student_code';
  static const String _passwordKey = 'secure_password';
  static const String _lastRefreshKey = 'last_auto_refresh';
  static const String _nextRefreshTimeKey = 'next_refresh_time';

  /// Initialize the auto-refresh service
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  /// Save login credentials securely (encrypted)
  static Future<void> saveCredentials(String studentCode, String password) async {
    try {
      await _storage.write(key: _studentCodeKey, value: studentCode);
      await _storage.write(key: _passwordKey, value: password);
      
      // Schedule the first auto-refresh
      await scheduleNextRefresh();
    } catch (e) {
      _log.log('Failed to save credentials: $e', level: LogLevel.error);
    }
  }

  /// Get stored credentials
  static Future<Map<String, String>?> getCredentials() async {
    try {
      final studentCode = await _storage.read(key: _studentCodeKey);
      final password = await _storage.read(key: _passwordKey);
      
      if (studentCode != null && password != null) {
        return {'studentCode': studentCode, 'password': password};
      }
      return null;
    } catch (e) {
      _log.log('Failed to read credentials: $e', level: LogLevel.error);
      return null;
    }
  }

  /// Clear stored credentials
  static Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _studentCodeKey);
      await _storage.delete(key: _passwordKey);
      await cancelAutoRefresh();
    } catch (e) {
      _log.log('Failed to clear credentials: $e', level: LogLevel.error);
    }
  }

  /// Schedule next auto-refresh at random time between 8 AM - 12 PM tomorrow
  static Future<void> scheduleNextRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Generate random time between 8 AM (8:00) and 12 PM (12:00) tomorrow
      final random = Random();
      final randomHour = 8 + random.nextInt(4); // 8, 9, 10, or 11
      final randomMinute = random.nextInt(60); // 0-59
      
      // Schedule for tomorrow at the random time
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        randomHour,
        randomMinute,
      );
      
      // If somehow the time is in the past, schedule for the day after
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      
      // Save next refresh time for user visibility
      await prefs.setInt(_nextRefreshTimeKey, scheduledTime.millisecondsSinceEpoch);
      
      // Schedule the alarm
      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        _alarmId,
        _performAutoRefresh,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      
      final timeStr = '${scheduledTime.day}/${scheduledTime.month} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      _log.log('Auto-refresh scheduled for: $timeStr', level: LogLevel.warning);
    } catch (e) {
      _log.log('Failed to schedule auto-refresh: $e', level: LogLevel.error);
    }
  }

  /// Cancel auto-refresh
  static Future<void> cancelAutoRefresh() async {
    try {
      await AndroidAlarmManager.cancel(_alarmId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_nextRefreshTimeKey);
    } catch (e) {
      _log.log('Failed to cancel auto-refresh: $e', level: LogLevel.error);
    }
  }

  /// Get next scheduled refresh time
  static Future<DateTime?> getNextRefreshTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_nextRefreshTimeKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Perform automatic refresh (called by AlarmManager)
  @pragma('vm:entry-point')
  static Future<void> _performAutoRefresh() async {
    final log = LogService();
    
    try {
      log.log('[AutoRefresh] Starting automatic data refresh...', level: LogLevel.warning);
      
      // Get stored credentials
      final credentials = await getCredentials();
      if (credentials == null) {
        log.log('[AutoRefresh] No credentials found, skipping refresh', level: LogLevel.warning);
        return;
      }
      
      final studentCode = credentials['studentCode']!;
      final password = credentials['password']!;
      
      // Authenticate silently
      final authService = AuthService();
      final loginResponse = await authService.login(studentCode, password);
      final accessToken = loginResponse.accessToken;
      
      log.log('[AutoRefresh] Authentication successful', level: LogLevel.warning);
      
      // Get database helper
      final dbHelper = DatabaseHelper.instance;
      
      // 1. Refresh user info
      final tluUser = await authService.getCurrentUser(accessToken);
      await dbHelper.saveTluUser(tluUser);
      
      // 2. Refresh school years and semesters
      final schoolYears = await authService.getSchoolYears(accessToken);
      await dbHelper.saveSchoolYears(schoolYears.content);
      
      // Find current semester
      final currentSemesterInfo = await authService.getSemesterInfo(accessToken);
      final currentSemesterId = currentSemesterInfo.id;
      
      // Create new semester objects with updated isCurrent flag
      final allSemesters = <Semester>[];
      for (var year in schoolYears.content) {
        for (var semester in year.semesters) {
          // Create new Semester with updated isCurrent
          final updatedSemester = Semester(
            id: semester.id,
            semesterCode: semester.semesterCode,
            semesterName: semester.semesterName,
            startDate: semester.startDate,
            endDate: semester.endDate,
            isCurrent: semester.id == currentSemesterId,
            ordinalNumbers: semester.ordinalNumbers,
            semesterRegisterPeriods: semester.semesterRegisterPeriods,
          );
          allSemesters.add(updatedSemester);
        }
      }
      await dbHelper.saveSemesters(allSemesters);
      
      // 3. Refresh course hours
      final courseHours = await authService.getCourseHours(accessToken);
      await dbHelper.saveCourseHours(courseHours);
      
      // 4. Refresh courses for current semester
      final courses = await authService.getStudentCourseSubject(
        accessToken,
        currentSemesterId,
      );
      await dbHelper.saveStudentCourses(currentSemesterId, courses);
      
      // 5. Refresh exam data for current semester
      try {
        final registerPeriods = await authService.getRegisterPeriods(
          accessToken,
          currentSemesterId,
        );
        await dbHelper.saveRegisterPeriods(currentSemesterId, registerPeriods);
        
        // Refresh exam rooms for each period and round
        for (var period in registerPeriods) {
          for (int round = 1; round <= 5; round++) {
            try {
              final examRooms = await authService.getStudentExamRooms(
                accessToken,
                currentSemesterId,
                period.id,
                round,
              );
              await dbHelper.saveExamRooms(
                currentSemesterId,
                period.id,
                round,
                examRooms,
              );
            } catch (e) {
              // Silently handle empty rounds
            }
          }
        }
      } catch (e) {
        log.log('[AutoRefresh] Exam data refresh failed: $e', level: LogLevel.warning);
      }
      
      // Save last refresh timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
      
      log.log('[AutoRefresh] Data refresh completed successfully!', level: LogLevel.warning);
      
      // Schedule next refresh for tomorrow
      await scheduleNextRefresh();
      
    } catch (e) {
      log.log('[AutoRefresh] Failed: $e', level: LogLevel.error);
      
      // Retry tomorrow anyway
      await scheduleNextRefresh();
    }
  }

  /// Get last refresh time
  static Future<DateTime?> getLastRefreshTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastRefreshKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if credentials are saved
  static Future<bool> hasStoredCredentials() async {
    final credentials = await getCredentials();
    return credentials != null;
  }

  /// Manually trigger refresh (for testing)
  static Future<void> triggerManualRefresh() async {
    await _performAutoRefresh();
  }
}
