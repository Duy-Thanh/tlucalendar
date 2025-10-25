import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/models/user.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/auth_service.dart';
import 'package:tlucalendar/services/database_helper.dart';

class UserProvider extends ChangeNotifier {
  late User _currentUser;
  late SharedPreferences _prefs;
  late AuthService _authService;
  final _dbHelper = DatabaseHelper.instance;
  bool _isLoggedIn = false;
  String? _accessToken;
  
  // New fields for TLU API data
  TluUser? _tluUser;
  SchoolYearResponse? _schoolYears;
  SemesterInfo? _currentSemesterInfo;
  Semester? _selectedSemester;
  Map<int, CourseHour> _courseHours = {};  // Map of CourseHour by ID
  List<StudentCourseSubject> _studentCourses = [];
  bool _isLoadingCourses = false;
  String? _courseLoadError;

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

  /// Initialize SharedPreferences and load saved login credentials
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isLoggedIn = _prefs.getBool(_isLoggedInKey) ?? false;
    _accessToken = _prefs.getString(_accessTokenKey);

    if (_isLoggedIn) {
      // Load cached data from database
      await _loadCachedData();
      
      // Try to refresh from API if token is valid
      if (_accessToken != null) {
        try {
          final isValid = await _authService.isTokenValid(_accessToken!);
          if (isValid) {
            // Token is valid, refresh data from API
            await _refreshFromApi();
          } else {
            // Token expired, use cached data
            _isLoggedIn = false;
          }
        } catch (e) {
          // Network error, use cached data
          print('Using cached data: $e');
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
          _studentCourses = await _dbHelper.getStudentCourses(_selectedSemester!.id);
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
      // Step 1: Get access token
      final loginResponse = await _authService.login(studentCode, password);
      _accessToken = loginResponse.accessToken;

      // Step 2: Fetch user data
      _tluUser = await _authService.getCurrentUser(_accessToken!);
      _updateUserFromTluUser(_tluUser!);
      await _dbHelper.saveTluUser(_tluUser!); // 💾 Save to database

      // Step 3: Fetch school years and semesters
      _schoolYears = await _authService.getSchoolYears(_accessToken!);
      
      // Step 4: Fetch current semester info
      _currentSemesterInfo = await _authService.getSemesterInfo(_accessToken!);
      
      // Step 5: Fetch all course hours (time slots) - needed to display times
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
      
      // Step 7: Load courses for selected semester
      if (_selectedSemester != null) {
        await loadCoursesForSemester(_selectedSemester!.id);
      }

      _isLoggedIn = true;

      // Save to device
      await _prefs.setString(_studentCodeKey, studentCode);
      await _prefs.setString(_passwordKey, password);
      await _prefs.setString(_accessTokenKey, loginResponse.accessToken);
      await _prefs.setString(_refreshTokenKey, loginResponse.refreshToken);
      await _prefs.setBool(_isLoggedInKey, true);

      notifyListeners();
    } catch (e) {
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
    if (_accessToken == null) return;
    
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
      
      // Try to load from database first
      final cachedCourses = await _dbHelper.getStudentCourses(semesterId);
      
      if (cachedCourses.isNotEmpty) {
        // Use cached data immediately
        _studentCourses = cachedCourses;
        _isLoadingCourses = false;
        notifyListeners();
      }
      
      // Then try to fetch fresh data from API in background
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
      } catch (apiError) {
        // API failed, but we have cached data - that's OK
        if (cachedCourses.isEmpty) {
          // No cache and API failed - this is a real error
          _courseLoadError = apiError.toString();
          rethrow;
        }
      }
      
      _isLoadingCourses = false;
      notifyListeners();
    } catch (e) {
      _courseLoadError = e.toString();
      _isLoadingCourses = false;
      notifyListeners();
      rethrow;
    }
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