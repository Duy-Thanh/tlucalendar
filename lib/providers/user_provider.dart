import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/models/user.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/auth_service.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/services/notification_service.dart';
import 'package:tlucalendar/services/daily_notification_service.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/services/download_foreground_service.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/utils/notification_helper.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UserProvider extends ChangeNotifier {
  late User _currentUser;
  late SharedPreferences _prefs;
  late AuthService _authService;
  final _dbHelper = DatabaseHelper.instance;
  final _log = LogService();
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
  
  // Notification settings
  bool _notificationsEnabled = true;
  bool _hasNotificationPermission = false;
  bool _dailyNotificationsEnabled = true;  // Daily morning summary

  static const String _studentCodeKey = 'userStudentCode';
  static const String _passwordKey = 'userPassword';
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _notificationsEnabledKey = 'notificationsEnabled';
  static const String _dailyNotificationsEnabledKey = 'dailyNotificationsEnabled';
  static const String _backgroundDownloadCompleteKey = 'backgroundDownloadComplete';
  static const String _backgroundDownloadInProgressKey = 'backgroundDownloadInProgress';

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
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hasNotificationPermission => _hasNotificationPermission;
  bool get dailyNotificationsEnabled => _dailyNotificationsEnabled;
  
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
    _notificationsEnabled = _prefs.getBool(_notificationsEnabledKey) ?? true;
    _dailyNotificationsEnabled = _prefs.getBool(_dailyNotificationsEnabledKey) ?? true;

    // Check actual notification permission status
    await checkNotificationPermission();

    if (_isLoggedIn) {
      // Load cached data from database first (works offline!)
      await _loadCachedData();

      // Check if foreground download service is already running
      final isDownloading = await DownloadForegroundService.isRunning();
      if (isDownloading) {
        _log.log('Foreground download service is already running', level: LogLevel.info);
      } else {
        // Resume background download if it was interrupted and service not running
        if (_accessToken != null) {
          final downloadComplete = _prefs.getBool('download_complete') ?? false;
          final downloadInProgress = _prefs.getBool('download_in_progress') ?? false;
          
          if (!downloadComplete || downloadInProgress) {
            _log.log('Resuming interrupted background download...', level: LogLevel.info);
            // Small delay to let UI initialize first
            Future.delayed(const Duration(seconds: 2), () {
              _downloadRemainingDataInBackground();
            });
          }
        }
      }

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
          _log.log('Using cached data (offline mode): $e', level: LogLevel.info);
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
          
          _log.log(
            'Loaded ${_studentCourses.length} courses for ${_selectedSemester!.semesterName} from cache',
            level: LogLevel.info,
          );
          
          // Notify UI to update with loaded courses
          notifyListeners();
          
          // Schedule notifications for the current week's classes
          await _scheduleNotificationsForCurrentWeek();
        }
      }
    } catch (e) {
      _log.log('Error loading cached data: $e', level: LogLevel.error);
    }
  }

  /// Refresh data from API
  Future<void> _refreshFromApi() async {
    try {
      final tluUser = await _authService.getCurrentUser(_accessToken!);
      _updateUserFromTluUser(tluUser);
      await _dbHelper.saveTluUser(tluUser);
    } catch (e) {
      _log.log('Error refreshing from API: $e', level: LogLevel.warning);
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
      // Reset progress and download flags for fresh login
      _loginProgress = 'Đang xác thực...';
      _loginProgressPercent = 0.0;
      await _prefs.setBool(_backgroundDownloadCompleteKey, false);
      await _prefs.setBool(_backgroundDownloadInProgressKey, false);
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

      // Step 7: Fetch ONLY current semester courses (fast login!)
      if (_selectedSemester != null) {
        _loginProgress = 'Đang tải lịch học hiện tại...';
        _loginProgressPercent = 0.625; // 5/8
        notifyListeners();

        try {
          _studentCourses = await _authService.getStudentCourseSubject(
            _accessToken!,
            _selectedSemester!.id,
          );

          // Save current semester courses to database
          await _dbHelper.saveStudentCourses(_selectedSemester!.id, _studentCourses);
          _log.log(
            'Saved ${_studentCourses.length} courses for current semester',
            level: LogLevel.success,
          );
        } catch (e) {
          _log.log(
            'Failed to fetch current semester courses: $e',
            level: LogLevel.warning,
          );
          // Try to load from cache
          try {
            _studentCourses = await _dbHelper.getStudentCourses(_selectedSemester!.id);
            _log.log('Loaded courses from cache', level: LogLevel.info);
          } catch (cacheError) {
            _log.log('No cached courses available', level: LogLevel.warning);
          }
        }
      }

      // Step 8: Skip full exam download during login (will be done in background)
      // User can enter app immediately!

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

      // 🚀 Start background download of remaining data (non-blocking)
      _log.log('Starting background data download...', level: LogLevel.info);
      _downloadRemainingDataInBackground();
      
      // 🚀 Also trigger exam pre-caching if ExamProvider is available
      if (_examProvider != null && _selectedSemester != null) {
        _log.log('Starting exam pre-caching...', level: LogLevel.info);
        Future.delayed(const Duration(seconds: 1), () {
          _examProvider!.preCacheAllExamData(_accessToken!, _selectedSemester!.id);
        });
      }
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

  /// Download remaining semesters' data in background (non-blocking)
  /// This runs after login completes, allowing user to use the app immediately
  /// Persists progress so it can resume if app is closed
  /// Uses foreground service to keep download alive even when app is backgrounded
  /// Download remaining semesters' data using foreground service
  /// This runs in a separate isolate and survives app exit
  Future<void> _downloadRemainingDataInBackground() async {
    try {
      _log.log('[Background] Starting foreground download service...', level: LogLevel.info);

      if (_schoolYears == null || _accessToken == null || _selectedSemester == null) {
        _log.log('[Background] Missing required data, skipping', level: LogLevel.warning);
        return;
      }

      final allSemesters = _schoolYears!.content
          .expand((y) => y.semesters)
          .toList();

      // Prepare semester data for isolate
      final semesterData = allSemesters.map((s) => {
        'id': s.id,
        'name': s.semesterName,
      }).toList();

      // Start foreground service with download logic
      final started = await DownloadForegroundService.startDownload(
        accessToken: _accessToken!,
        semesters: semesterData,
        currentSemesterId: _selectedSemester!.id,
      );

      if (started) {
        _log.log('[Background] Foreground service started successfully', level: LogLevel.success);
        
        // Show toast notification to user
        Fluttertoast.showToast(
          msg: "Quá trình tải xuống dữ liệu đang diễn ra, vui lòng kiểm tra thông báo!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 4,
          backgroundColor: Colors.blue[700],
          textColor: Colors.white,
          fontSize: 14.0,
        );
      } else {
        _log.log('[Background] Failed to start foreground service', level: LogLevel.error);
      }
    } catch (e) {
      _log.log('[Background] Error starting download: $e', level: LogLevel.error);
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
          _log.log(
            'Using cached data for semester $semesterId (offline or API error): $apiError',
            level: LogLevel.info,
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
    // Check if notifications are enabled
    if (!_notificationsEnabled) {
      _log.log('Notifications are disabled by user', level: LogLevel.info);
      return;
    }

    // Check if permission is granted
    if (!_hasNotificationPermission) {
      _log.log('Notification permission not granted', level: LogLevel.warning);
      return;
    }

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
    
    _log.log('Scheduling notifications for $weeksToSchedule weeks (respecting platform limits)', level: LogLevel.info);
    if (weeksUntilEnd > maxWeeksToSchedule) {
      _log.log('Note: Only scheduling next $maxWeeksToSchedule weeks due to platform limits', level: LogLevel.info);
      _log.log('Notifications will be rescheduled when you reopen the app', level: LogLevel.info);
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
        _log.log('Failed to schedule notifications for week $weekOffset: $e', level: LogLevel.warning);
      }
    }
    
    _log.log('Notifications scheduled for $weeksToSchedule weeks', level: LogLevel.success);
    _log.log('Tip: Reopen the app weekly to keep notifications up to date', level: LogLevel.info);
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
    
    // Clear background download flags
    await _prefs.setBool(_backgroundDownloadCompleteKey, false);
    await _prefs.setBool(_backgroundDownloadInProgressKey, false);
    
    _isLoggedIn = false;
    _accessToken = null;

    // Clear exam provider state to prevent endless loading after re-login
    _examProvider?.clear();

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

  /// Toggle notifications on/off
  /// Returns true if toggle was successful, false if permission denied
  Future<bool> toggleNotifications(bool enabled) async {
    // If disabling, just turn off
    if (!enabled) {
      _notificationsEnabled = false;
      await _prefs.setBool(_notificationsEnabledKey, false);
      notifyListeners();
      return true;
    }

    // If enabling, check current permission status first
    // ✅ REMOVED _isLoggedIn check - notifications should work even when not logged in!
    if (enabled) {
      // First, check if permission was granted in system settings
      _hasNotificationPermission = 
          await NotificationService().areNotificationsEnabled();
      
      if (!_hasNotificationPermission) {
        // Permission not granted, try to request it
        _hasNotificationPermission =
            await NotificationService().requestPermissions();

        // If permission still denied, DON'T change the saved state
        // This allows user to grant permission in settings and try again
        if (!_hasNotificationPermission) {
          _log.log('Notification permission denied by user', level: LogLevel.warning);
          // ✅ DON'T save false to SharedPreferences!
          // Keep the toggle state as it was, so user can try again after granting permission
          notifyListeners();
          return false; // Toggle failed, but state not saved
        }
      }
      
      // Permission granted, enable notifications
      _notificationsEnabled = true;
      await _prefs.setBool(_notificationsEnabledKey, true);
      
      // Only schedule notifications if logged in
      if (_isLoggedIn) {
        await _scheduleNotificationsForCurrentWeek();
      }
      
      notifyListeners();
      return true;
    }

    notifyListeners();
    return true;
  }

  /// Check if notification permission is granted
  Future<void> checkNotificationPermission() async {
    _hasNotificationPermission =
        await NotificationService().areNotificationsEnabled();
    notifyListeners();
  }

  /// Toggle daily morning notifications on/off
  Future<void> toggleDailyNotifications(bool enabled) async {
    _dailyNotificationsEnabled = enabled;
    await _prefs.setBool(_dailyNotificationsEnabledKey, enabled);
    
    if (enabled) {
      await DailyNotificationService.scheduleDailyCheck();
      _log.log('Daily notifications enabled', level: LogLevel.success);
    } else {
      await DailyNotificationService.cancelDailyCheck();
      _log.log('Daily notifications disabled', level: LogLevel.info);
    }
    
    notifyListeners();
  }
}
