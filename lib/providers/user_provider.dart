import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/models/user.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/auth_service.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/services/notification_service.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/utils/notification_helper.dart';

class UserProvider extends ChangeNotifier {
  late User _currentUser;
  late SharedPreferences _prefs;
  late AuthService _authService;
  final _dbHelper = DatabaseHelper.instance;
  bool _isLoggedIn = false;
  String? _accessToken;
  ExamProvider? _examProvider; // Optional reference to ExamProvider

  // New fields for TLU API data
  TluUser? _tluUser;
  SchoolYearResponse? _schoolYears;
  SemesterInfo? _currentSemesterInfo;
  Semester? _selectedSemester;
  Map<int, CourseHour> _courseHours = {}; // Map of CourseHour by ID
  List<StudentCourseSubject> _studentCourses = [];
  bool _isLoadingCourses = false;
  String? _courseLoadError;
  
  // Login progress tracking
  String _loginProgress = '';
  double _loginProgressPercent = 0.0;

  static const String _studentCodeKey = 'userStudentCode';
  static const String _passwordKey = 'userPassword';
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _isLoggedInKey = 'isLoggedIn';

  User get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get accessToken => _accessToken;
  TluUser? get tluUser => _tluUser;
  SchoolYearResponse? get schoolYears => _schoolYears;
  SemesterInfo? get currentSemesterInfo => _currentSemesterInfo;
  Semester? get selectedSemester => _selectedSemester;
  Map<int, CourseHour> get courseHours => _courseHours;
  List<StudentCourseSubject> get studentCourses => _studentCourses;
  bool get isLoadingCourses => _isLoadingCourses;
  String? get courseLoadError => _courseLoadError;
  
  // Login progress getters
  String get loginProgress => _loginProgress;
  double get loginProgressPercent => _loginProgressPercent;

  /// Get semester start date for week calculation
  DateTime? get semesterStartDate {
    if (_selectedSemester != null) {
      return DateTime.fromMillisecondsSinceEpoch(_selectedSemester!.startDate);
    }
    return null;
  }

  /// Find semester that contains the given date
  Semester? getSemesterForDate(DateTime date) {
    if (_schoolYears == null) return null;

    final dateMs = date.millisecondsSinceEpoch;

    // Search through all semesters to find one that contains this date
    for (var year in _schoolYears!.content) {
      for (var semester in year.semesters) {
        if (dateMs >= semester.startDate && dateMs <= semester.endDate) {
          return semester;
        }
      }
    }

    return null;
  }

  /// Get filtered courses that are active on a specific date
  /// Only returns courses if they belong to the currently selected semester
  List<StudentCourseSubject> getActiveCourses(DateTime date) {
    if (semesterStartDate == null) {
      return _studentCourses;
    }

    return _studentCourses.where((course) {
      return course.isActiveOn(date, semesterStartDate!);
    }).toList();
  }

  /// Check if a given date belongs to the currently selected semester
  bool isDateInCurrentSemester(DateTime date) {
    if (_selectedSemester == null) return false;

    final dateMs = date.millisecondsSinceEpoch;
    return dateMs >= _selectedSemester!.startDate &&
        dateMs <= _selectedSemester!.endDate;
  }

  UserProvider() {
    // Initialize with sample user
    _currentUser = User(
      studentId: '123456789',
      fullName: 'Guest User',
      email: 'Guest User',
    );
    _authService = AuthService();
  }

  /// Set exam provider reference for fetching exam data during login
  void setExamProvider(ExamProvider examProvider) {
    _examProvider = examProvider;
  }

  /// Initialize SharedPreferences and load saved login credentials
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isLoggedIn = _prefs.getBool(_isLoggedInKey) ?? false;
    _accessToken = _prefs.getString(_accessTokenKey);

    if (_isLoggedIn) {
      // Load cached data from database first (works offline!)
      await _loadCachedData();

      // Try to refresh from API if we have network (optional)
      if (_accessToken != null) {
        try {
          final isValid = await _authService.isTokenValid(_accessToken!);
          if (isValid) {
            // Token is valid, refresh data from API in background
            await _refreshFromApi();
          }
          // Note: If token is invalid, we still keep user logged in with cached data
          // They can manually logout if needed
        } catch (e) {
          // Network error - that's fine! We have cached data
          print('Using cached data (offline mode): $e');
          // Keep _isLoggedIn = true so user can access cached data
        }
      }
    }
    notifyListeners();
  }

  /// Load cached data from local database
  Future<void> _loadCachedData() async {
    try {
      // Load user
      _tluUser = await _dbHelper.getTluUser();
      if (_tluUser != null) {
        _updateUserFromTluUser(_tluUser!);
      }

      // Load course hours
      _courseHours = await _dbHelper.getCourseHours();

      // Load school years and semesters
      final schoolYears = await _dbHelper.getSchoolYears();
      final semesters = await _dbHelper.getSemesters();

      if (schoolYears.isNotEmpty && semesters.isNotEmpty) {
        // Group semesters by school year
        for (var year in schoolYears) {
          year.semesters.clear();
          year.semesters.addAll(
            semesters.where((s) {
              // Match semesters to school years by date range
              return s.startDate >= year.startDate && s.endDate <= year.endDate;
            }).toList(),
          );
        }

        _schoolYears = SchoolYearResponse(
          content: schoolYears,
          last: true,
          totalElements: schoolYears.length,
          totalPages: 1,
        );

        // Find active semester
        _selectedSemester = semesters.firstWhere(
          (s) => s.isActive(),
          orElse: () => semesters.first,
        );

        // Load courses for selected semester
        if (_selectedSemester != null) {
          _studentCourses = await _dbHelper.getStudentCourses(
            _selectedSemester!.id,
          );
          
          // Schedule notifications for the current week's classes
          await _scheduleNotificationsForCurrentWeek();
        }
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  /// Refresh data from API
  Future<void> _refreshFromApi() async {
    try {
      final tluUser = await _authService.getCurrentUser(_accessToken!);
      _updateUserFromTluUser(tluUser);
      await _dbHelper.saveTluUser(tluUser);
    } catch (e) {
      print('Error refreshing from API: $e');
    }
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Update user from TLU API response
  void _updateUserFromTluUser(TluUser tluUser) {
    _currentUser = User(
      studentId: tluUser.username,
      fullName: tluUser.displayName,
      email: tluUser.email,
    );
  }

  /// Login with real TLU API
  Future<void> loginWithApi(String studentCode, String password) async {
    try {
      // Reset progress
      _loginProgress = 'Đang xác thực...';
      _loginProgressPercent = 0.0;
      notifyListeners();
      
      // Step 1: Get access token
      final loginResponse = await _authService.login(studentCode, password);
      _accessToken = loginResponse.accessToken;

      // Step 2: Fetch user data
      _loginProgress = 'Đang tải thông tin người dùng...';
      _loginProgressPercent = 0.125; // 1/8
      notifyListeners();
      
      _tluUser = await _authService.getCurrentUser(_accessToken!);
      _updateUserFromTluUser(_tluUser!);
      await _dbHelper.saveTluUser(_tluUser!); // 💾 Save to database

      // Step 3: Fetch school years and semesters
      _loginProgress = 'Đang tải danh sách học kỳ...';
      _loginProgressPercent = 0.25; // 2/8
      notifyListeners();
      
      _schoolYears = await _authService.getSchoolYears(_accessToken!);

      // Step 4: Fetch current semester info
      _loginProgress = 'Đang tải thông tin học kỳ hiện tại...';
      _loginProgressPercent = 0.375; // 3/8
      notifyListeners();
      
      _currentSemesterInfo = await _authService.getSemesterInfo(_accessToken!);

      // Step 5: Fetch all course hours (time slots) - needed to display times
      _loginProgress = 'Đang tải thông tin tiết học...';
      _loginProgressPercent = 0.5; // 4/8
      notifyListeners();
      
      _courseHours = await _authService.getCourseHours(_accessToken!);
      await _dbHelper.saveCourseHours(_courseHours); // 💾 Save to database

      // Step 6: Find and set selected semester (current semester based on actual dates)
      if (_schoolYears != null) {
        // Save school years to database
        await _dbHelper.saveSchoolYears(_schoolYears!.content);

        // Save all semesters to database
        final allSemesters = _schoolYears!.content
            .expand((y) => y.semesters)
            .toList();
        await _dbHelper.saveSemesters(allSemesters);

        // First, try to find a semester that is currently active (today's date falls within it)
        _selectedSemester = _schoolYears!.content
            .expand((y) => y.semesters)
            .firstWhere(
              (s) => s.isActive(),
              orElse: () {
                // If no active semester found, use the one marked as isCurrent
                try {
                  return _schoolYears!.content
                      .expand((y) => y.semesters)
                      .firstWhere((s) => s.isCurrent);
                } catch (e) {
                  // Last resort: use first semester
                  return _schoolYears!.content[0].semesters[0];
                }
              },
            );
      }

      // Step 7: Fetch and save courses for ALL semesters (for offline use!)
      if (_schoolYears != null) {
        final allSemesters = _schoolYears!.content
            .expand((y) => y.semesters)
            .toList();

        _loginProgress = 'Đang tải lịch học (0/${allSemesters.length})...';
        _loginProgressPercent = 0.625; // 5/8
        notifyListeners();

        print(
          '📥 Downloading courses for ALL ${allSemesters.length} semesters...',
        );

        for (var i = 0; i < allSemesters.length; i++) {
          final semester = allSemesters[i];
          try {
            _loginProgress = 'Đang tải lịch học (${i + 1}/${allSemesters.length})...';
            notifyListeners();
            
            final courses = await _authService.getStudentCourseSubject(
              _accessToken!,
              semester.id,
            );

            // Save to database
            await _dbHelper.saveStudentCourses(semester.id, courses);
            print(
              '✅ Saved ${courses.length} courses for semester ${semester.semesterName}',
            );

            // If this is the selected semester, update current courses
            if (semester.id == _selectedSemester?.id) {
              _studentCourses = courses;
            }
          } catch (e) {
            print(
              '⚠️ Failed to fetch courses for semester ${semester.semesterName}: $e',
            );
            // Continue with other semesters even if one fails
          }
        }

        print('🎉 All semester data downloaded and cached!');
      }

      // Step 8: Fetch and save exam data for ALL semesters (for offline use!)
      if (_schoolYears != null && _examProvider != null && _accessToken != null) {
        final allSemesters = _schoolYears!.content
            .expand((y) => y.semesters)
            .toList();

        _loginProgress = 'Đang tải lịch thi (0/${allSemesters.length})...';
        _loginProgressPercent = 0.75; // 6/8
        notifyListeners();

        print(
          '📥 Downloading exam schedules for ALL ${allSemesters.length} semesters...',
        );

        for (var i = 0; i < allSemesters.length; i++) {
          final semester = allSemesters[i];
          try {
            _loginProgress = 'Đang tải lịch thi (${i + 1}/${allSemesters.length})...';
            notifyListeners();
            
            // Fetch register periods for this semester
            final periods = await _authService.getRegisterPeriods(
              _accessToken!,
              semester.id,
            );

            // Save register periods to database
            await _dbHelper.saveRegisterPeriods(semester.id, periods);
            print(
              '✅ Saved ${periods.length} register periods for semester ${semester.semesterName}',
            );

            // For each register period, fetch exam rooms for round 1
            for (var period in periods) {
              try {
                final examRooms = await _authService.getStudentExamRooms(
                  _accessToken!,
                  semester.id,
                  period.id,
                  1, // Default to exam round 1
                );

                // Save exam rooms to database
                await _dbHelper.saveExamRooms(
                  semester.id,
                  period.id,
                  1,
                  examRooms,
                );
                print(
                  '✅ Saved ${examRooms.length} exam rooms for ${semester.semesterName} - ${period.name} - Round 1',
                );
              } catch (e) {
                print(
                  '⚠️ Failed to fetch exam rooms for ${semester.semesterName} - ${period.name}: $e',
                );
                // Continue with other periods
              }
            }
          } catch (e) {
            print(
              '⚠️ Failed to fetch exam data for semester ${semester.semesterName}: $e',
            );
            // Continue with other semesters even if one fails
          }
        }

        print('🎉 All exam data downloaded and cached!');
      }

      // Final step: Save credentials
      _loginProgress = 'Đang hoàn tất...';
      _loginProgressPercent = 0.95; // Almost done
      notifyListeners();

      _isLoggedIn = true;

      // Save to device
      await _prefs.setString(_studentCodeKey, studentCode);
      await _prefs.setString(_passwordKey, password);
      await _prefs.setString(_accessTokenKey, loginResponse.accessToken);
      await _prefs.setString(_refreshTokenKey, loginResponse.refreshToken);
      await _prefs.setBool(_isLoggedInKey, true);

      // Complete!
      _loginProgress = 'Hoàn tất!';
      _loginProgressPercent = 1.0;
      notifyListeners();
    } catch (e) {
      // Reset progress on error
      _loginProgress = '';
      _loginProgressPercent = 0.0;
      
      _isLoggedIn = false;
      _accessToken = null;
      _schoolYears = null;
      _currentSemesterInfo = null;
      _selectedSemester = null;
      _courseHours = {};
      _studentCourses = [];
      rethrow;
    }
  }

  /// Load courses for a specific semester
  Future<void> loadCoursesForSemester(int semesterId) async {
    // Update selected semester
    if (_schoolYears != null) {
      for (var year in _schoolYears!.content) {
        for (var semester in year.semesters) {
          if (semester.id == semesterId) {
            _selectedSemester = semester;
            break;
          }
        }
      }
    }

    try {
      _isLoadingCourses = true;
      _courseLoadError = null;
      notifyListeners();

      // Load from database first (works offline!)
      final cachedCourses = await _dbHelper.getStudentCourses(semesterId);

      // Always use cached data if available
      _studentCourses = cachedCourses;
      _isLoadingCourses = false;
      notifyListeners();

      // Schedule notifications for this week's classes
      await _scheduleNotificationsForCurrentWeek();

      // Try to fetch fresh data from API in background (only if online)
      if (_accessToken != null) {
        try {
          final freshCourses = await _authService.getStudentCourseSubject(
            _accessToken!,
            semesterId,
          );

          // Update with fresh data (even if empty - that's valid!)
          _studentCourses = freshCourses;

          // 💾 Save courses to database
          await _dbHelper.saveStudentCourses(semesterId, _studentCourses);

          notifyListeners();

          // Re-schedule notifications with fresh data
          await _scheduleNotificationsForCurrentWeek();
        } catch (apiError) {
          // API failed (offline or network error)
          // We already loaded cached data above, so just log it
          print(
            'Using cached data for semester $semesterId (offline or API error): $apiError',
          );
        }
      }
    } catch (e) {
      _courseLoadError = e.toString();
      _isLoadingCourses = false;
      notifyListeners();
    }
  }

  /// Schedule notifications for all upcoming classes
  /// 
  /// Platform Limitations:
  /// - iOS: Maximum 64 pending notifications (iOS 10+)
  /// - Android: Samsung limits to 500 notifications, some OEMs may have lower limits
  /// - Solution: Schedule only next 4 weeks, then reschedule when app reopens
  Future<void> _scheduleNotificationsForCurrentWeek() async {
    if (_studentCourses.isEmpty || _courseHours.isEmpty || semesterStartDate == null) {
      return;
    }

    // Clear all existing notifications to prevent accumulation
    // This ensures we stay under platform limits
    // await NotificationService().cancelAllNotifications();
    // print('🗑️ Cleared all existing notifications');

    // Platform notification limits:
    // - iOS: 64 notifications max
    // - Android: 500 on Samsung, varies by OEM
    // - Each class has 3 notifications (1h, 30m, 15m)
    // Strategy: Schedule 4 weeks ahead to stay well under limits
    // This gives ~12 classes × 3 notifications × 4 weeks = ~144 notifications
    // Well under iOS 64 limit per week, and total stays reasonable
    const maxWeeksToSchedule = 4;

    // Get semester end date
    final semesterEnd = _selectedSemester != null 
        ? DateTime.fromMillisecondsSinceEpoch(_selectedSemester!.endDate)
        : DateTime.now().add(const Duration(days: 120)); // Default 120 days if no semester

    final now = DateTime.now();
    final weekday = now.weekday; // 1=Monday, 7=Sunday
    final currentWeekStart = now.subtract(Duration(days: weekday - 1));
    
    // Calculate how many weeks until semester ends
    final weeksUntilEnd = semesterEnd.difference(currentWeekStart).inDays ~/ 7;
    
    // Limit to maxWeeksToSchedule to respect platform constraints
    final weeksToSchedule = weeksUntilEnd > maxWeeksToSchedule 
        ? maxWeeksToSchedule 
        : (weeksUntilEnd > 0 ? weeksUntilEnd : 1);
    
    print('📅 Scheduling notifications for $weeksToSchedule weeks (respecting platform limits)');
    if (weeksUntilEnd > maxWeeksToSchedule) {
      print('   ℹ️ Note: Only scheduling next $maxWeeksToSchedule weeks due to platform limits');
      print('   ℹ️ Notifications will be rescheduled when you reopen the app');
    }
    
    // Schedule for the next few weeks
    for (int weekOffset = 0; weekOffset < weeksToSchedule; weekOffset++) {
      final weekStart = currentWeekStart.add(Duration(days: 7 * weekOffset));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      try {
        await NotificationHelper.scheduleWeekClassNotifications(
          courses: _studentCourses,
          courseHours: _courseHours,
          weekStartDate: weekStartDate,
          semesterStartDate: semesterStartDate!,
        );
      } catch (e) {
        print('⚠️ Failed to schedule notifications for week $weekOffset: $e');
      }
    }
    
    print('✅ Notifications scheduled for $weeksToSchedule weeks');
    print('   💡 Tip: Reopen the app weekly to keep notifications up to date');
  }

  /// Change selected semester and load courses
  Future<void> selectSemester(Semester semester) async {
    _selectedSemester = semester;
    await loadCoursesForSemester(semester.id);
  }

  /// Log out and clear saved credentials
  Future<void> logout() async {
    await _prefs.remove(_studentCodeKey);
    await _prefs.remove(_passwordKey);
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.setBool(_isLoggedInKey, false);
    _isLoggedIn = false;
    _accessToken = null;

    // Reset to sample user
    _currentUser = User(
      studentId: '2251061884',
      fullName: 'Nekkochan',
      email: 'nekkochan@tlu.edu.vn',
    );
    notifyListeners();
  }

  /// Get saved student code (if exists)
  String? getSavedStudentCode() {
    return _prefs.getString(_studentCodeKey);
  }

  /// Get saved password (if exists)
  String? getSavedPassword() {
    return _prefs.getString(_passwordKey);
  }
}
