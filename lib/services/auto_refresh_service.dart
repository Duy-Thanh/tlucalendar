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
@pragma('vm:entry-point')
class AutoRefreshService {
  static const int _alarmId = 100; // Unique ID for auto-refresh alarm
  static const _storage = FlutterSecureStorage();
  static final _log = LogService();
  
  // Secure storage keys
  static const String _studentCodeKey = 'secure_student_code';
  static const String _passwordKey = 'secure_password';
  static const String _lastRefreshKey = 'last_auto_refresh';
  static const String _nextRefreshTimeKey = 'next_refresh_time';
  static const String _dataRefreshPendingKey = 'data_refresh_pending';

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

  /// Show notification helper
  /// Note: Notifications don't work reliably in background isolates
  /// So we just log instead - users can check logs to see progress
  static Future<void> _showNotification(String title, String body) async {
    // Skip notifications in background context - they cause NullPointerException
    // because there's no Flutter UI context available in AlarmManager callback
    return;
  }

  /// Perform automatic refresh (called by AlarmManager)
  @pragma('vm:entry-point')
  static Future<void> _performAutoRefresh() async {
    final log = LogService();
    final startTime = DateTime.now();
    
    try {
      log.log('[AutoRefresh] ⏰ Starting automatic data refresh...', level: LogLevel.warning);
      await _showNotification('Cập nhật tự động', 'Đang bắt đầu cập nhật dữ liệu...');
      
      // Get stored credentials
      log.log('[AutoRefresh] 🔐 Reading stored credentials...', level: LogLevel.warning);
      final credentials = await getCredentials();
      if (credentials == null) {
        log.log('[AutoRefresh] ❌ No credentials found, skipping refresh', level: LogLevel.warning);
        await _showNotification('Cập nhật thất bại', 'Không tìm thấy thông tin đăng nhập');
        return;
      }
      
      final studentCode = credentials['studentCode']!;
      final password = credentials['password']!;
      log.log('[AutoRefresh] ✓ Credentials loaded for: $studentCode', level: LogLevel.warning);
      
      // Authenticate silently
      log.log('[AutoRefresh] 🔑 Authenticating...', level: LogLevel.warning);
      final authService = AuthService();
      final loginResponse = await authService.login(studentCode, password);
      final accessToken = loginResponse.accessToken;
      
      log.log('[AutoRefresh] ✓ Authentication successful', level: LogLevel.warning);
      await _showNotification('Cập nhật tự động', 'Đã xác thực thành công, đang tải dữ liệu...');
      
      // Get database helper and ensure it's initialized for background isolate
      log.log('[AutoRefresh] 💾 Ensuring database connection...', level: LogLevel.warning);
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.ensureInitialized(); // Ensure connection is available
      log.log('[AutoRefresh] ✓ Database connection ready', level: LogLevel.warning);
      
      // 1. Refresh user info
      log.log('[AutoRefresh] 📥 Fetching user info...', level: LogLevel.warning);
      final tluUser = await authService.getCurrentUser(accessToken);
      await dbHelper.saveTluUser(tluUser);
      log.log('[AutoRefresh] ✓ User info saved: ${tluUser.displayName}', level: LogLevel.warning);
      
      // 2. Refresh school years and semesters
      log.log('[AutoRefresh] 📥 Fetching school years...', level: LogLevel.warning);
      final schoolYears = await authService.getSchoolYears(accessToken);
      await dbHelper.saveSchoolYears(schoolYears.content);
      log.log('[AutoRefresh] ✓ Saved ${schoolYears.content.length} school years', level: LogLevel.warning);
      
      // Find current semester
      log.log('[AutoRefresh] 📥 Fetching current semester info...', level: LogLevel.warning);
      final currentSemesterInfo = await authService.getSemesterInfo(accessToken);
      final currentSemesterId = currentSemesterInfo.id;
      log.log('[AutoRefresh] ✓ Current semester: ${currentSemesterInfo.semesterName}', level: LogLevel.warning);
      
      // Create new semester objects with updated isCurrent flag
      log.log('[AutoRefresh] 🔄 Processing semesters...', level: LogLevel.warning);
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
      log.log('[AutoRefresh] ✓ Saved ${allSemesters.length} semesters', level: LogLevel.warning);
      
      // 3. Refresh course hours
      log.log('[AutoRefresh] 📥 Fetching course hours...', level: LogLevel.warning);
      final courseHours = await authService.getCourseHours(accessToken);
      await dbHelper.saveCourseHours(courseHours);
      log.log('[AutoRefresh] ✓ Saved ${courseHours.length} course hours', level: LogLevel.warning);
      
      // 4. Refresh courses for current semester
      log.log('[AutoRefresh] 📥 Fetching courses for current semester...', level: LogLevel.warning);
      final courses = await authService.getStudentCourseSubject(
        accessToken,
        currentSemesterId,
      );
      await dbHelper.saveStudentCourses(currentSemesterId, courses);
      log.log('[AutoRefresh] ✓ Saved ${courses.length} courses', level: LogLevel.warning);
      await _showNotification('Cập nhật tự động', 'Đã tải xong lịch học, đang tải lịch thi...');
      
      // 5. Refresh exam data for current semester
      log.log('[AutoRefresh] 📥 Fetching exam periods...', level: LogLevel.warning);
      try {
        final registerPeriods = await authService.getRegisterPeriods(
          accessToken,
          currentSemesterId,
        );
        await dbHelper.saveRegisterPeriods(currentSemesterId, registerPeriods);
        log.log('[AutoRefresh] ✓ Found ${registerPeriods.length} exam periods', level: LogLevel.warning);
        
        // Refresh exam rooms for each period and round
        int totalRooms = 0;
        for (var period in registerPeriods) {
          log.log('[AutoRefresh] 📥 Fetching exam rooms for period: ${period.name}', level: LogLevel.warning);
          for (int round = 1; round <= 5; round++) {
            try {
              final examRooms = await authService.getStudentExamRooms(
                accessToken,
                currentSemesterId,
                period.id,
                round,
              );
              if (examRooms.isNotEmpty) {
                await dbHelper.saveExamRooms(
                  currentSemesterId,
                  period.id,
                  round,
                  examRooms,
                );
                totalRooms += examRooms.length;
                log.log('[AutoRefresh] ✓ Saved ${examRooms.length} exam rooms for round $round', level: LogLevel.warning);
              }
            } catch (e) {
              // Silently handle empty rounds
              log.log('[AutoRefresh] ⚠ No exam rooms for round $round', level: LogLevel.warning);
            }
          }
        }
        log.log('[AutoRefresh] ✓ Total exam rooms saved: $totalRooms', level: LogLevel.warning);
      } catch (e) {
        log.log('[AutoRefresh] ⚠ Exam data refresh failed: $e', level: LogLevel.warning);
      }
      
      // Save last refresh timestamp and set pending flag
      final prefs = await SharedPreferences.getInstance();
      final endTime = DateTime.now();
      await prefs.setInt(_lastRefreshKey, endTime.millisecondsSinceEpoch);
      await prefs.setBool(_dataRefreshPendingKey, true); // Flag for UI update
      
      final duration = endTime.difference(startTime);
      log.log('[AutoRefresh] ✅ Data refresh completed successfully in ${duration.inSeconds}s!', level: LogLevel.warning);
      log.log('[AutoRefresh] 🔔 Data refresh pending flag SET - UI will update on app resume', level: LogLevel.warning);
      await _showNotification(
        'Cập nhật hoàn tất',
        'Dữ liệu đã được cập nhật thành công (${duration.inSeconds}s)',
      );
      
      // 🔒 Close database after background task to prevent memory leaks & security issues
      await dbHelper.closeForBackground();
      log.log('[AutoRefresh] 💾 Database closed securely after background refresh', level: LogLevel.warning);
      
      // Schedule next refresh for tomorrow
      await scheduleNextRefresh();
      
    } catch (e, stackTrace) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      log.log('[AutoRefresh] ❌ Failed after ${duration.inSeconds}s: $e', level: LogLevel.error);
      log.log('[AutoRefresh] Stack trace: ${stackTrace.toString().substring(0, stackTrace.toString().length > 500 ? 500 : stackTrace.toString().length)}', level: LogLevel.error);
      await _showNotification(
        'Cập nhật thất bại',
        'Lỗi: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}',
      );
      
      // 🔒 Close database even on error to prevent leaks
      try {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.closeForBackground();
        log.log('[AutoRefresh] 💾 Database closed after error', level: LogLevel.warning);
      } catch (closeError) {
        log.log('[AutoRefresh] ⚠️ Failed to close database: $closeError', level: LogLevel.warning);
      }
      
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

  /// Check if data was refreshed while app was closed
  static Future<bool> isDataRefreshPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_dataRefreshPendingKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Clear the data refresh pending flag after UI is updated
  static Future<void> clearDataRefreshPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dataRefreshPendingKey, false);
    } catch (e) {
      // Silently fail
    }
  }
}
