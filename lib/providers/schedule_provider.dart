import 'package:flutter/material.dart';

import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/native/native_parser.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_course_hours_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_current_semester_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:tlucalendar/services/notification_service.dart';

import 'package:tlucalendar/providers/auth_provider.dart';

class ScheduleProvider extends ChangeNotifier {
  final GetScheduleUseCase getScheduleUseCase;
  final GetSchoolYearsUseCase getSchoolYearsUseCase;
  final GetCurrentSemesterUseCase getCurrentSemesterUseCase;
  final GetCourseHoursUseCase getCourseHoursUseCase;

  AuthProvider? _authProvider;

  ScheduleProvider({
    required this.getScheduleUseCase,
    required this.getSchoolYearsUseCase,
    required this.getCurrentSemesterUseCase,
    required this.getCourseHoursUseCase,
  });

  void setAuthProvider(AuthProvider auth) {
    _authProvider = auth;
  }

  // State
  List<SchoolYear> _schoolYears = [];
  List<Course> _courses = [];
  List<CourseHour> _courseHours = [];
  Semester? _currentSemester;

  bool _isOfflineMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<SchoolYear> get schoolYears => _schoolYears;
  List<Course> get courses => _courses;
  List<CourseHour> get courseHours => _courseHours;
  Semester? get currentSemester => _currentSemester;
  Semester? get selectedSemester =>
      _currentSemester; // Alias for UI if needed, or implement distinct selection
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOfflineMode => _isOfflineMode;

  // Init Data
  Future<void> init(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    _isOfflineMode = false;
    notifyListeners();

    String currentToken = accessToken;

    try {
      // 1. Fetch School Years (with Auto-Relogin)
      var yearsResult = await getSchoolYearsUseCase(currentToken);

      bool shouldRetry = false;
      yearsResult.fold((f) {
        if (f is! CachedDataFailure) shouldRetry = true;
      }, (r) {});

      if (shouldRetry && _authProvider != null) {
        debugPrint('Initial fetch failed, attempting auto-relogin...');
        if (await _authProvider!.reLogin()) {
          currentToken = _authProvider!.accessToken!;
          yearsResult = await getSchoolYearsUseCase(currentToken);
        }
      }

      await yearsResult.fold(
        (failure) async {
          if (failure is CachedDataFailure<List<SchoolYear>>) {
            _isOfflineMode = true;
            // Continue with cached data
            _processSchoolYears(failure.data);
          } else {
            _errorMessage = failure.message;
          }
        },
        (years) async {
          _processSchoolYears(years);
        },
      );

      // 3. Fetch Course Hours (pass potentially updated token)
      await _fetchCourseHours(currentToken);

      // 4. If we have a current semester, load its schedule
      if (_currentSemester != null) {
        await loadSchedule(currentToken, _currentSemester!.id);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _processSchoolYears(List<SchoolYear> years) async {
    _schoolYears = years;
    _schoolYears.sort((a, b) => a.startDate.compareTo(b.startDate));

    // 2. Determine Current Semester
    Semester? foundCurrent;
    for (var y in years) {
      for (var s in y.semesters) {
        if (s.isCurrent) {
          foundCurrent = s;
          break;
        }
      }
    }

    if (foundCurrent == null &&
        years.isNotEmpty &&
        years.last.semesters.isNotEmpty) {
      foundCurrent = years.last.semesters.last;
    }

    _currentSemester = foundCurrent;
  }

  Future<void> _fetchCourseHours(String accessToken) async {
    String currentToken = accessToken;
    var hoursResult = await getCourseHoursUseCase(currentToken);

    bool shouldRetry = false;
    hoursResult.fold((f) {
      if (f is! CachedDataFailure) shouldRetry = true;
    }, (r) {});

    if (shouldRetry && _authProvider != null) {
      if (await _authProvider!.reLogin()) {
        currentToken = _authProvider!.accessToken!;
        hoursResult = await getCourseHoursUseCase(currentToken);
      }
    }

    hoursResult.fold(
      (failure) {
        if (failure is CachedDataFailure<List<CourseHour>>) {
          _courseHours = failure.data;
          // If we fallback to cache for hours, it effectively means we are partially offline.
          // But since the main indicator is School Years, we just quietly use this data properly.
          debugPrint('Using cached Course Hours due to: ${failure.message}');
        } else {
          // Non-blocking failure for auxiliary data
          debugPrint('Failed to fetch Course Hours: ${failure.message}');
        }
      },
      (hours) {
        _courseHours = hours;
      },
    );
  }

  Future<void> selectSemester(String accessToken, int semesterId) async {
    // Find semester object
    Semester? found;
    for (var y in _schoolYears) {
      final s = y.semesters.where((s) => s.id == semesterId).firstOrNull;
      if (s != null) {
        found = s;
        break;
      }
    }

    if (found != null) {
      _currentSemester = found;
      await loadSchedule(accessToken, semesterId);
    }
  }

  Future<void> loadSchedule(String accessToken, int semesterId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String currentToken = accessToken;

    var result = await getScheduleUseCase(
      GetScheduleParams(accessToken: currentToken, semesterId: semesterId),
    );

    bool shouldRetry = false;
    result.fold((f) {
      if (f is! CachedDataFailure) shouldRetry = true;
    }, (r) {});

    if (shouldRetry && _authProvider != null) {
      if (await _authProvider!.reLogin()) {
        currentToken = _authProvider!.accessToken!;
        result = await getScheduleUseCase(
          GetScheduleParams(accessToken: currentToken, semesterId: semesterId),
        );
      }
    }

    result.fold(
      (f) {
        if (f is CachedDataFailure<List<Course>>) {
          _isOfflineMode = true;
          _courses = f.data;
          _scheduleNotifications();
        } else {
          _errorMessage = f.message;
        }
      },
      (c) {
        _isOfflineMode = false;
        _courses = c;
        _scheduleNotifications();
      },
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _scheduleNotifications() async {
    // delay to avoid blocking immediate UI updates
    await Future.delayed(Duration.zero);

    if (_currentSemester == null || _courses.isEmpty) return;

    final notificationService = NotificationService();

    // Clear all previous notifications
    await notificationService.cancelAllNotifications();

    // Optimized Native Notification Generation
    if (_currentSemester == null) return;

    final notifications = NativeParser.generateNotifications(
      _currentSemester!.startDate,
    );

    if (notifications.isEmpty && _courses.isNotEmpty) {
      debugPrint("Native Notifications returned empty! Using Dart fallback.");
      await _scheduleDartNotifications(notificationService);
      return;
    }

    // Batch processing to prevent UI freezer (Davey)
    int count = 0;
    for (var n in notifications) {
      await notificationService.scheduleNativeClassNotification(n);
      count++;
      // Yield every 20 items to let UI breathe
      if (count % 20 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  Future<void> _scheduleDartNotifications(
    NotificationService notificationService,
  ) async {
    if (_courseHours.isEmpty) return; // Need course hours to know times

    int count = 0;
    for (var course in _courses) {
      // Find start hour
      final startHourObj = _courseHours.firstWhere(
        (h) => h.id == course.startCourseHour,
        orElse: () => _courseHours.first, // Fallback?
      );

      // Parse start time "07:00"
      final timeParts = startHourObj.startString.split(':');
      if (timeParts.length < 2) continue;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Calculate dates for this course

      final semesterStart = DateTime.fromMillisecondsSinceEpoch(
        _currentSemester!.startDate,
      );

      // Iterate weeks
      for (int w = course.fromWeek; w <= course.toWeek; w++) {
        // Calculate date relative to Semester Start
        // Week 1 starts at startDate.
        // Week w starts at startDate + (w-1)*7 days.
        // Then add (dayOfWeek - 2) days. (Mon=2 -> add 0).

        final weekStart = semesterStart.add(Duration(days: (w - 1) * 7));
        // TLU dayOfWeek: 2=Mon ... 8=Sun.
        // Dart DateTime: 1=Mon ... 7=Sun.
        // weekStart is usually Monday? Assumed.
        // We need to align with specific day.

        // Let's assume startDate is Monday of Week 1.

        final offsetDays = course.dayOfWeek - 2; // 2->0, 3->1...
        final classDate = weekStart.add(Duration(days: offsetDays));

        // Combine with time
        final classDateTime = DateTime(
          classDate.year,
          classDate.month,
          classDate.day,
          hour,
          minute,
        );

        await notificationService.scheduleClassNotifications(
          course,
          classDateTime,
          course.dayOfWeek,
          "${startHourObj.startString}-${startHourObj.endString}",
        );

        count++;
        if (count % 20 == 0)
          await Future.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  // Get active courses for a date
  List<Course> getActiveCourses(DateTime date) {
    // 2=Monday...8=Sunday (TLU)
    // date.weekday: 1=Monday...7=Sunday (Dart)
    final tluDayOfWeek = date.weekday + 1;

    return _courses.where((course) {
      return course.dayOfWeek == tluDayOfWeek && course.isActiveOn(date);
    }).toList();
  }
}
