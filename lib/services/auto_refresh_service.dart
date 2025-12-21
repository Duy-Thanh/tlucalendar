import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/models/api_response.dart' as legacy;

// Injection and UseCases
import 'package:tlucalendar/injection_container.dart' as di;
import 'package:tlucalendar/features/auth/domain/usecases/login_usecase.dart';
import 'package:tlucalendar/features/auth/domain/usecases/get_user_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_current_semester_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_course_hours_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_schedules_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_rooms_usecase.dart';

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
  static Future<void> saveCredentials(
    String studentCode,
    String password,
  ) async {
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
      await prefs.setInt(
        _nextRefreshTimeKey,
        scheduledTime.millisecondsSinceEpoch,
      );

      // Schedule the alarm
      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        _alarmId,
        _performAutoRefresh,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      final timeStr =
          '${scheduledTime.day}/${scheduledTime.month} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
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
  static Future<void> _showNotification(String title, String body) async {
    // Skip notifications in background context
    return;
  }

  /// Perform automatic refresh (called by AlarmManager)
  @pragma('vm:entry-point')
  static Future<void> _performAutoRefresh() async {
    final log = LogService();
    final startTime = DateTime.now();

    try {
      // Initialize Dependency Injection for this isolate
      await di.init();

      log.log(
        '[AutoRefresh] ⏰ Starting automatic data refresh...',
        level: LogLevel.warning,
      );
      await _showNotification(
        'Cập nhật tự động',
        'Đang bắt đầu cập nhật dữ liệu...',
      );

      // Get stored credentials
      log.log(
        '[AutoRefresh] 🔐 Reading stored credentials...',
        level: LogLevel.warning,
      );
      final credentials = await getCredentials();
      if (credentials == null) {
        log.log(
          '[AutoRefresh] ❌ No credentials found, skipping refresh',
          level: LogLevel.warning,
        );
        await _showNotification(
          'Cập nhật thất bại',
          'Không tìm thấy thông tin đăng nhập',
        );
        return;
      }

      final studentCode = credentials['studentCode']!;
      final password = credentials['password']!;
      log.log(
        '[AutoRefresh] ✓ Credentials loaded for: $studentCode',
        level: LogLevel.warning,
      );

      // Resolve UseCases
      final loginUseCase = di.sl<LoginUseCase>();
      final getUserUseCase = di.sl<GetUserUseCase>();
      final getSchoolYearsUseCase = di.sl<GetSchoolYearsUseCase>();
      final getCurrentSemesterUseCase = di.sl<GetCurrentSemesterUseCase>();
      final getCourseHoursUseCase = di.sl<GetCourseHoursUseCase>();
      final getScheduleUseCase = di.sl<GetScheduleUseCase>();
      final getExamSchedulesUseCase = di.sl<GetExamSchedulesUseCase>();
      final getExamRoomsUseCase = di.sl<GetExamRoomsUseCase>();

      // Authenticate silently
      log.log('[AutoRefresh] 🔑 Authenticating...', level: LogLevel.warning);
      final loginResult = await loginUseCase(
        LoginParams(studentCode: studentCode, password: password),
      );

      String accessToken = '';

      // Handle login result
      await loginResult.fold(
        (failure) async {
          throw Exception('Login failed: ${failure.message}');
        },
        (token) async {
          accessToken = token;
        },
      );

      if (accessToken.isEmpty) {
        throw Exception('Access token is empty');
      }

      log.log(
        '[AutoRefresh] ✓ Authentication successful',
        level: LogLevel.warning,
      );
      await _showNotification(
        'Cập nhật tự động',
        'Đã xác thực thành công, đang tải dữ liệu...',
      );

      // Get database helper and ensure it's initialized for background isolate
      log.log(
        '[AutoRefresh] 💾 Ensuring database connection...',
        level: LogLevel.warning,
      );
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.ensureInitialized(); // Ensure connection is available
      log.log(
        '[AutoRefresh] ✓ Database connection ready',
        level: LogLevel.warning,
      );

      // 1. Refresh user info
      log.log(
        '[AutoRefresh] 📥 Fetching user info...',
        level: LogLevel.warning,
      );
      final userResult = await getUserUseCase(accessToken);

      await userResult.fold(
        (failure) async => log.log(
          '[AutoRefresh] ⚠ Failed to get user info: ${failure.message}',
          level: LogLevel.warning,
        ),
        (user) async {
          // Map to Legacy TluUser
          final tluUser = legacy.TluUser(
            username: user.studentId,
            displayName: user.fullName,
            email: user.email,
            id: 0, // Mock ID as it's not critical for local caching usually
            active: true,
            roles: [], // Mock empty roles
          );
          await dbHelper.saveTluUser(tluUser);
          log.log(
            '[AutoRefresh] ✓ User info saved: ${tluUser.displayName}',
            level: LogLevel.warning,
          );
        },
      );

      // 2. Refresh school years, semesters, and current semester
      log.log(
        '[AutoRefresh] 📥 Fetching school years...',
        level: LogLevel.warning,
      );

      final yearResult = await getSchoolYearsUseCase(accessToken);

      int currentSemesterId = 0;

      await yearResult.fold(
        (failure) =>
            throw Exception('Failed to get school years: ${failure.message}'),
        (years) async {
          // Fetch Current Semester Info to get ID
          final currentResult = await getCurrentSemesterUseCase(accessToken);

          await currentResult.fold(
            (failure) async => log.log(
              '[AutoRefresh] ⚠ Failed to get current semester info: ${failure.message}',
              level: LogLevel.warning,
            ),
            (currentSem) async {
              currentSemesterId = currentSem.id;
              log.log(
                '[AutoRefresh] ✓ Current semester ID: $currentSemesterId',
                level: LogLevel.warning,
              );
            },
          );

          // Map SchoolYears and Semesters to Legacy
          final legacyYears = <legacy.SchoolYear>[];
          final allSemesters = <legacy.Semester>[];

          for (var y in years) {
            final semList = y.semesters
                .map(
                  (s) => legacy.Semester(
                    id: s.id,
                    semesterCode: s.semesterCode,
                    semesterName: s.semesterName,
                    startDate: s.startDate,
                    endDate: s.endDate,
                    isCurrent: s.id == currentSemesterId, // Logic from original
                    ordinalNumbers: s.ordinalNumbers,
                    semesterRegisterPeriods:
                        [], // Not used for basic semester model
                  ),
                )
                .toList();

            // Add to all semesters list
            allSemesters.addAll(semList);

            legacyYears.add(
              legacy.SchoolYear(
                id: y.id,
                name: y.name,
                code: y.code,
                year: y.year,
                current: y.current,
                startDate: y.startDate,
                endDate: y.endDate,
                displayName: y.displayName,
                semesters: semList,
              ),
            );
          }

          await dbHelper.saveSchoolYears(legacyYears);
          await dbHelper.saveSemesters(allSemesters);
          log.log(
            '[AutoRefresh] ✓ Saved ${legacyYears.length} school years and ${allSemesters.length} semesters',
            level: LogLevel.warning,
          );
        },
      );

      // 3. Refresh course hours
      log.log(
        '[AutoRefresh] 📥 Fetching course hours...',
        level: LogLevel.warning,
      );
      final hoursResult = await getCourseHoursUseCase(accessToken);
      await hoursResult.fold(
        (failure) async => log.log(
          '[AutoRefresh] ⚠ Failed to get course hours: ${failure.message}',
          level: LogLevel.warning,
        ),
        (hours) async {
          // Map to expected Map<int, CourseHour>
          final Map<int, legacy.CourseHour> hoursMap = {};
          for (var h in hours) {
            hoursMap[h.id] = legacy.CourseHour(
              id: h.id,
              name: h.name,
              startString: h.startString,
              endString: h.endString,
              indexNumber: h.indexNumber,
              type: 0, // Mock default
              start: 0,
              end: 0,
            );
          }
          await dbHelper.saveCourseHours(hoursMap);
          log.log(
            '[AutoRefresh] ✓ Saved ${hours.length} course hours',
            level: LogLevel.warning,
          );
        },
      );

      // 4. Refresh courses for current semester
      if (currentSemesterId != 0) {
        log.log(
          '[AutoRefresh] 📥 Fetching courses for current semester ($currentSemesterId)...',
          level: LogLevel.warning,
        );
        final courseResult = await getScheduleUseCase(
          GetScheduleParams(
            semesterId: currentSemesterId,
            accessToken: accessToken,
          ),
        );

        await courseResult.fold(
          (failure) async => log.log(
            '[AutoRefresh] ⚠ Failed to get courses: ${failure.message}',
            level: LogLevel.warning,
          ),
          (courses) async {
            // Map Entity -> Legacy StudentCourseSubject
            final legacyCourses = courses
                .map(
                  (c) => legacy.StudentCourseSubject(
                    id: c.id,
                    courseCode: c.courseCode,
                    courseName: c.courseName,
                    classCode: c.classCode ?? '',
                    className: c.className ?? '',
                    dayOfWeek: c.dayOfWeek,
                    startCourseHour: c.startCourseHour,
                    endCourseHour: c.endCourseHour,
                    room: c.room,
                    building: c.building ?? '',
                    campus: c.campus ?? '',
                    credits: c.credits,
                    startDate: c.startDate,
                    endDate: c.endDate,
                    fromWeek: c.fromWeek,
                    toWeek: c.toWeek,
                    status: c.status,
                    grade: c.grade,
                    lecturer: c.lecturerName != null
                        ? legacy.LecturerInfo(
                            id: 0,
                            name: c.lecturerName!,
                            email: c.lecturerEmail ?? '',
                          )
                        : null,
                  ),
                )
                .toList();

            await dbHelper.saveStudentCourses(currentSemesterId, legacyCourses);
            log.log(
              '[AutoRefresh] ✓ Saved ${legacyCourses.length} courses',
              level: LogLevel.warning,
            );
          },
        );

        await _showNotification(
          'Cập nhật tự động',
          'Đã tải xong lịch học, đang tải lịch thi...',
        );

        // 5. Refresh exam data for current semester
        log.log(
          '[AutoRefresh] 📥 Fetching exam periods...',
          level: LogLevel.warning,
        );

        final schedResult = await getExamSchedulesUseCase(
          GetExamSchedulesParams(
            semesterId: currentSemesterId,
            accessToken: accessToken,
          ),
        );

        await schedResult.fold(
          (failure) async => log.log(
            '[AutoRefresh] ⚠ Exam schedule fetch failed: ${failure.message}',
            level: LogLevel.warning,
          ),
          (schedules) async {
            // Map Entity -> Legacy RegisterPeriod
            final registerPeriods = schedules
                .map(
                  (s) => legacy.RegisterPeriod(
                    id: s.id,
                    voided: s.voided,
                    // Create minimal Semester object required by constructor
                    semester: legacy.Semester(
                      id: currentSemesterId,
                      semesterCode: '',
                      semesterName: '',
                      startDate: 0,
                      endDate: 0,
                      isCurrent: false,
                      semesterRegisterPeriods: [],
                    ),
                    name: s.name,
                    displayOrder: s.displayOrder,
                    examPeriods: [],
                  ),
                )
                .toList();

            await dbHelper.saveRegisterPeriods(
              currentSemesterId,
              registerPeriods,
            );
            log.log(
              '[AutoRefresh] ✓ Found ${registerPeriods.length} exam periods',
              level: LogLevel.warning,
            );

            // Refresh exam rooms
            for (var period in registerPeriods) {
              log.log(
                '[AutoRefresh] 📥 Fetching exam rooms for period: ${period.name}',
                level: LogLevel.warning,
              );
              for (int round = 1; round <= 5; round++) {
                final roomResult = await getExamRoomsUseCase(
                  GetExamRoomsParams(
                    semesterId: currentSemesterId,
                    scheduleId: period.id,
                    round: round,
                    accessToken: accessToken,
                  ),
                );

                await roomResult.fold(
                  (failure) async => null, // Silent fail for round
                  (rooms) async {
                    if (rooms.isNotEmpty) {
                      // Map Entity -> Legacy StudentExamRoom
                      final legacyRooms = rooms
                          .map(
                            (r) => legacy.StudentExamRoom(
                              id: r.id,
                              status: 0,
                              examCode: '',
                              examCodeNumber: 0,
                              markingCode: '',
                              examPeriodCode: r.examPeriodCode,
                              subjectName: r.subjectName,
                              studentCode: r.studentCode,
                              examRound: round,
                              examRoom: legacy.ExamRoomDetail(
                                id: 0,
                                roomCode: r.roomName ?? '',
                                duration: 0,
                                examDate: r.examDate?.millisecondsSinceEpoch,
                                examDateString: r.examDate?.toIso8601String(),
                                numberExpectedStudent: 0,
                                semesterName: '',
                                courseYearName: '',
                                registerPeriodName: '',
                                examHour: legacy.ExamHour(
                                  id: 0,
                                  startString: r.examTime ?? '',
                                  endString: '',
                                  name: '',
                                  code: '',
                                ),
                                room: legacy.Room(
                                  id: 0,
                                  name: r.roomName ?? '',
                                  code: '',
                                ),
                              ),
                            ),
                          )
                          .toList();

                      await dbHelper.saveExamRooms(
                        currentSemesterId,
                        period.id,
                        round,
                        legacyRooms,
                      );
                      log.log(
                        '[AutoRefresh] ✓ Saved ${legacyRooms.length} exam rooms for round $round',
                        level: LogLevel.warning,
                      );
                    }
                  },
                );
              }
            }
          },
        );
      }

      // Save last refresh timestamp and set pending flag
      final prefs = await SharedPreferences.getInstance();
      final endTime = DateTime.now();
      await prefs.setInt(_lastRefreshKey, endTime.millisecondsSinceEpoch);
      await prefs.setBool(_dataRefreshPendingKey, true); // Flag for UI update

      final duration = endTime.difference(startTime);
      log.log(
        '[AutoRefresh] ✅ Data refresh completed successfully in ${duration.inSeconds}s!',
        level: LogLevel.warning,
      );
      log.log(
        '[AutoRefresh] 🔔 Data refresh pending flag SET - UI will update on app resume',
        level: LogLevel.warning,
      );
      await _showNotification(
        'Cập nhật hoàn tất',
        'Dữ liệu đã được cập nhật thành công (${duration.inSeconds}s)',
      );

      // Don't close database - main app may still need it (SQLite)

      // Schedule next refresh for tomorrow
      await scheduleNextRefresh();
    } catch (e, stackTrace) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      log.log(
        '[AutoRefresh] ❌ Failed after ${duration.inSeconds}s: $e',
        level: LogLevel.error,
      );
      log.log(
        '[AutoRefresh] Stack trace: ${stackTrace.toString().substring(0, stackTrace.toString().length > 500 ? 500 : stackTrace.toString().length)}',
        level: LogLevel.error,
      );
      await _showNotification(
        'Cập nhật thất bại',
        'Lỗi: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}',
      );

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
