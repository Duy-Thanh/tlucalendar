import 'package:flutter/material.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/auth_service.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/utils/notification_helper.dart';

class ExamProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<RegisterPeriod> _registerPeriods = [];
  List<Semester> _availableSemesters = [];
  List<StudentExamRoom> _examRooms = [];
  bool _isLoading = false;
  bool _isLoadingSemesters = false;
  bool _isLoadingRooms = false;
  String? _errorMessage;
  String? _roomErrorMessage;

  // Pre-caching progress tracking
  bool _isPreCaching = false;
  int _preCacheProgress = 0; // 0-100 percentage
  String _preCacheStatus = '';
  int _preCacheTotalSemesters = 0;
  int _preCacheCurrentSemester = 0;
  int _preCacheTotalPeriods = 0;
  int _preCacheCurrentPeriod = 0;

  // Selected filters
  int? _selectedRegisterPeriodId;
  int? _selectedSemesterId;
  int _selectedExamRound = 1; // Default to round 1

  List<RegisterPeriod> get registerPeriods => _registerPeriods;
  List<Semester> get availableSemesters => _availableSemesters;
  List<StudentExamRoom> get examRooms => _examRooms;
  bool get isLoading => _isLoading;
  bool get isLoadingSemesters => _isLoadingSemesters;
  bool get isLoadingRooms => _isLoadingRooms;
  String? get errorMessage => _errorMessage;
  String? get roomErrorMessage => _roomErrorMessage;
  int? get selectedRegisterPeriodId => _selectedRegisterPeriodId;
  int? get selectedSemesterId => _selectedSemesterId;
  int get selectedExamRound => _selectedExamRound;

  // Pre-caching progress getters
  bool get isPreCaching => _isPreCaching;
  int get preCacheProgress => _preCacheProgress;
  String get preCacheStatus => _preCacheStatus;
  int get preCacheTotalSemesters => _preCacheTotalSemesters;
  int get preCacheCurrentSemester => _preCacheCurrentSemester;
  int get preCacheTotalPeriods => _preCacheTotalPeriods;
  int get preCacheCurrentPeriod => _preCacheCurrentPeriod;

  /// Get the currently selected register period
  RegisterPeriod? get selectedRegisterPeriod {
    if (_selectedRegisterPeriodId == null) return null;
    try {
      return _registerPeriods.firstWhere(
        (period) => period.id == _selectedRegisterPeriodId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get the currently selected semester
  Semester? get selectedSemester {
    if (_selectedSemesterId == null) return null;
    try {
      return _availableSemesters.firstWhere(
        (semester) => semester.id == _selectedSemesterId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if register periods cache exists for a semester
  Future<bool> hasRegisterPeriodsCache(int semesterId) async {
    return await _dbHelper.hasRegisterPeriodsCache(semesterId);
  }

  /// Select semester from cache only (no API call)
  Future<void> selectSemesterFromCache(int semesterId) async {
    _selectedSemesterId = semesterId;
    _selectedRegisterPeriodId = null;
    _examRooms = [];
    _selectedExamRound = 1;
    notifyListeners();

    // Load register periods from cache
    _isLoading = true;
    notifyListeners();

    try {
      _registerPeriods = await _dbHelper.getRegisterPeriods(semesterId);
      _registerPeriods.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Auto-select the first period if available
      if (_registerPeriods.isNotEmpty) {
        _selectedRegisterPeriodId = _registerPeriods.first.id;
        
        // Try to load exam rooms for the first period from cache
        final hasExamCache = await _dbHelper.hasExamRoomCache(
          semesterId,
          _registerPeriods.first.id,
          1,
        );
        
        if (hasExamCache) {
          _examRooms = await _dbHelper.getExamRooms(
            semesterId,
            _registerPeriods.first.id,
            1,
          );
          
          // Schedule notifications for cached exam data
          await _scheduleExamNotifications();
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch all available semesters
  Future<void> fetchAvailableSemesters(String? accessToken) async {
    _isLoadingSemesters = true;
    notifyListeners();

    // Skip if no access token (offline mode)
    if (accessToken == null || accessToken.isEmpty) {
      _isLoadingSemesters = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _authService.getAllSemesters(accessToken);
      _availableSemesters = response.content;

      // Sort by ordinalNumbers descending (newest first)
      _availableSemesters.sort(
        (a, b) => (b.ordinalNumbers ?? 0).compareTo(a.ordinalNumbers ?? 0),
      );

      _isLoadingSemesters = false;
      notifyListeners();
    } catch (e) {
      // Silently fail - not critical if we can't load all semesters
      print('Failed to load available semesters: $e');
      _isLoadingSemesters = false;
      notifyListeners();
    }
  }

  /// Select a semester and fetch its exam schedule
  Future<void> selectSemester(String? accessToken, int semesterId) async {
    _selectedSemesterId = semesterId;
    _selectedRegisterPeriodId = null; // Reset register period selection
    _examRooms = []; // Clear exam rooms when semester changes
    _selectedExamRound = 1; // Reset exam round to 1
    _isLoading = true; // Show loading state immediately
    notifyListeners();

    await fetchExamSchedule(accessToken, semesterId);
    
    // After fetching register periods, pre-cache all exam rounds for offline use
    if (_selectedRegisterPeriodId != null && _selectedSemesterId != null && accessToken != null) {
      print('[DEBUG] selectSemester: Pre-caching all exam rounds for offline use');
      
      // Fetch exam rooms for the selected round (will be displayed)
      await fetchExamRoomDetails(
        accessToken,
        _selectedSemesterId!,
        _selectedRegisterPeriodId!,
        _selectedExamRound,
      );
      
      // Pre-cache other rounds in background (silently, don't block UI)
      _preCacheExamRounds(
        accessToken,
        _selectedSemesterId!,
        _selectedRegisterPeriodId!,
        _selectedExamRound,
      );
    }
    // Note: _isLoading is set to false in fetchExamSchedule
  }

  /// Check if there's incomplete cache (for showing resume button)
  Future<bool> checkIncompletCache() async {
    try {
      final isComplete = await _dbHelper.isCacheComplete();
      final cachedSemesters = await _dbHelper.getCachedSemesterIds();
      // Incomplete if not marked complete AND has some cached data
      return !isComplete && cachedSemesters.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Pre-cache ALL exam data on login for full offline mode
  /// EXHAUSTIVE CACHING: Cache every single semester, period, and round
  /// Supports resuming from where it left off if app closes mid-cache
  Future<void> preCacheAllExamData(String accessToken, int currentSemesterId) async {
    _isPreCaching = true;
    _preCacheProgress = 0;
    _preCacheStatus = 'Bắt đầu tải dữ liệu offline...';
    notifyListeners();
    
    print('[PRE-CACHE] 🚀 EXHAUSTIVE CACHING MODE - Caching ALL data...');
    print('[PRE-CACHE] Current semester ID: $currentSemesterId');
    
    try {
      // Check if caching was already complete
      final isComplete = await _dbHelper.isCacheComplete();
      if (isComplete) {
        print('[PRE-CACHE] ✅ Cache already complete! No need to re-cache.');
        _isPreCaching = false;
        _preCacheProgress = 100;
        _preCacheStatus = 'Dữ liệu đã được tải đầy đủ';
        notifyListeners();
        return;
      }
      
      // Get list of already cached semesters (for resume capability)
      final cachedSemesterIds = await _dbHelper.getCachedSemesterIds();
      print('[PRE-CACHE] 📂 Already cached ${cachedSemesterIds.length} semesters');
      
      // Step 1: Fetch ALL available semesters
      print('[PRE-CACHE] ═══════════════════════════════════════════');
      print('[PRE-CACHE] Step 1: Fetching ALL semesters...');
      _preCacheStatus = 'Đang lấy danh sách học kỳ...';
      notifyListeners();
      
      final allSemesters = await _authService.getAllSemesters(accessToken);
      _preCacheTotalSemesters = allSemesters.content.length;
      print('[PRE-CACHE] ✅ Found $_preCacheTotalSemesters semesters total');
      print('[PRE-CACHE] 📦 Will cache EVERY semester for 100% offline mode!');
      
      // Filter out already cached semesters (for resume)
      final semestersToCache = allSemesters.content
          .where((sem) => !cachedSemesterIds.contains(sem.id))
          .toList();
      
      if (semestersToCache.isEmpty) {
        print('[PRE-CACHE] ✅ All semesters already cached!');
        await _dbHelper.updateCacheProgress(
          totalSemesters: _preCacheTotalSemesters,
          cachedSemesters: _preCacheTotalSemesters,
          isComplete: true,
        );
        
        _isPreCaching = false;
        _preCacheProgress = 100;
        _preCacheStatus = 'Hoàn tất! Tất cả dữ liệu đã sẵn sàng';
        notifyListeners();
        return;
      }
      
      print('[PRE-CACHE] 📝 Need to cache ${semestersToCache.length} remaining semesters');
      
      int totalPeriods = 0;
      int totalRounds = 0;
      int totalRooms = 0;
      
      // Step 2: Cache EVERY REMAINING SEMESTER
      for (int i = 0; i < semestersToCache.length; i++) {
        final sem = semestersToCache[i];
        _preCacheCurrentSemester = cachedSemesterIds.length + i + 1;
        
        print('[PRE-CACHE] ═══════════════════════════════════════════');
        print('[PRE-CACHE] Caching semester $_preCacheCurrentSemester/$_preCacheTotalSemesters');
        print('[PRE-CACHE] Semester: ${sem.semesterName} (ID: ${sem.id})');
        
        _preCacheStatus = 'Đang tải học kỳ ${sem.semesterName} ($_preCacheCurrentSemester/$_preCacheTotalSemesters)';
        _preCacheProgress = ((_preCacheCurrentSemester - 1) * 100 / _preCacheTotalSemesters).round();
        notifyListeners();
        
        // Update database progress
        await _dbHelper.updateCacheProgress(
          totalSemesters: _preCacheTotalSemesters,
          cachedSemesters: _preCacheCurrentSemester - 1,
          isComplete: false,
          currentSemesterId: sem.id,
          currentSemesterName: sem.semesterName,
        );
        
        try {
          // Fetch and cache register periods for this semester
          print('[PRE-CACHE]   → Fetching register periods...');
          final periods = await _authService.getRegisterPeriods(
            accessToken,
            sem.id,
          );
          await _dbHelper.saveRegisterPeriods(sem.id, periods);
          totalPeriods += periods.length;
          _preCacheTotalPeriods = periods.length;
          print('[PRE-CACHE]   ✅ Cached ${periods.length} register periods');
          
          // For EVERY register period, cache ALL 5 exam rounds
          for (int j = 0; j < periods.length; j++) {
            final period = periods[j];
            _preCacheCurrentPeriod = j + 1;
            
            print('[PRE-CACHE]   → Period $_preCacheCurrentPeriod/$_preCacheTotalPeriods: ${period.name}');
            _preCacheStatus = '${sem.semesterName}: Đợt ${period.name} ($_preCacheCurrentPeriod/$_preCacheTotalPeriods)';
            notifyListeners();
            
            for (int round = 1; round <= 5; round++) {
              try {
                final rooms = await _authService.getStudentExamRooms(
                  accessToken,
                  sem.id,
                  period.id,
                  round,
                );
                
                await _dbHelper.saveExamRooms(
                  sem.id,
                  period.id,
                  round,
                  rooms,
                );
                totalRounds++;
                totalRooms += rooms.length;
                
                if (rooms.isNotEmpty) {
                  print('[PRE-CACHE]     ✅ Round $round: ${rooms.length} room(s)');
                } else {
                  print('[PRE-CACHE]     ○ Round $round: empty (cached)');
                }
              } catch (e) {
                print('[PRE-CACHE]     ⚠️ Round $round: ${e.toString().substring(0, 50)}...');
                // Continue even if one round fails
              }
            }
          }
          
          print('[PRE-CACHE]   ✅ Semester ${sem.semesterName} complete!');
          
          // Update progress after completing this semester
          await _dbHelper.updateCacheProgress(
            totalSemesters: _preCacheTotalSemesters,
            cachedSemesters: _preCacheCurrentSemester,
            isComplete: false,
            currentSemesterId: sem.id,
            currentSemesterName: sem.semesterName,
          );
          
        } catch (e) {
          print('[PRE-CACHE]   ❌ Failed to cache semester ${sem.semesterName}: $e');
          // Continue with next semester even if this one fails
        }
      }
      
      // Mark caching as complete
      await _dbHelper.updateCacheProgress(
        totalSemesters: _preCacheTotalSemesters,
        cachedSemesters: _preCacheTotalSemesters,
        isComplete: true,
      );
      
      print('[PRE-CACHE] ═══════════════════════════════════════════');
      print('[PRE-CACHE] 🎉 EXHAUSTIVE CACHING COMPLETE!');
      print('[PRE-CACHE] 📊 Summary:');
      print('[PRE-CACHE]   • Semesters cached: ${allSemesters.content.length}');
      print('[PRE-CACHE]   • Register periods cached: $totalPeriods');
      print('[PRE-CACHE]   • Exam rounds cached: $totalRounds');
      print('[PRE-CACHE]   • Total exam rooms: $totalRooms');
      print('[PRE-CACHE] 💪 App now works 100% offline - even for 100 years!');
      print('[PRE-CACHE] ═══════════════════════════════════════════');
      
      _isPreCaching = false;
      _preCacheProgress = 100;
      _preCacheStatus = 'Hoàn tất! Ứng dụng có thể hoạt động offline';
      notifyListeners();
      
    } catch (e) {
      print('[PRE-CACHE] ❌ Pre-caching failed: $e');
      _isPreCaching = false;
      _preCacheStatus = 'Lỗi: $e';
      notifyListeners();
      // Don't throw - app should still work even if pre-caching fails
    }
  }
  
  /// Pre-cache all exam rounds in background for offline use
  Future<void> _preCacheExamRounds(
    String accessToken,
    int semesterId,
    int registerPeriodId,
    int currentRound,
  ) async {
    print('[DEBUG] _preCacheExamRounds: Caching rounds 1-5 for offline use');
    
    // Cache all 5 rounds (skip the current one since it's already cached)
    for (int round = 1; round <= 5; round++) {
      if (round == currentRound) continue; // Skip current round
      
      try {
        print('[DEBUG] _preCacheExamRounds: Caching round $round...');
        final rooms = await _authService.getStudentExamRooms(
          accessToken,
          semesterId,
          registerPeriodId,
          round,
        );
        
        // Save to cache
        await _dbHelper.saveExamRooms(
          semesterId,
          registerPeriodId,
          round,
          rooms,
        );
        print('[DEBUG] _preCacheExamRounds: Round $round cached (${rooms.length} rooms)');
      } catch (e) {
        // Silently fail - not critical if pre-caching fails
        print('[DEBUG] _preCacheExamRounds: Failed to cache round $round: $e');
      }
    }
    print('[DEBUG] _preCacheExamRounds: Pre-caching complete!');
  }
  
  /// Fetch exam schedule (register periods) for a semester
  Future<void> fetchExamSchedule(String? accessToken, int semesterId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try to load from cache first
      final hasCache = await _dbHelper.hasRegisterPeriodsCache(semesterId);
      print('[DEBUG] fetchExamSchedule: hasCache=$hasCache, semesterId=$semesterId');
      
      if (hasCache) {
        _registerPeriods = await _dbHelper.getRegisterPeriods(semesterId);
        print('[DEBUG] fetchExamSchedule: Loaded ${_registerPeriods.length} periods from cache');
        
        // Sort by display order
        _registerPeriods.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        // Auto-select the first period if none selected
        if (_registerPeriods.isNotEmpty && _selectedRegisterPeriodId == null) {
          _selectedRegisterPeriodId = _registerPeriods.first.id;
        }

        _isLoading = false;
        notifyListeners();

        // Fetch fresh data in background ONLY if we have valid access token
        if (accessToken != null && accessToken.isNotEmpty) {
          print('[DEBUG] fetchExamSchedule: Starting background refresh');
          _fetchExamScheduleFromApi(accessToken, semesterId);
        }
        return;
      }

      // No cache, try to fetch from API if we have access token
      print('[DEBUG] fetchExamSchedule: No cache, trying API');
      if (accessToken != null && accessToken.isNotEmpty) {
        await _fetchExamScheduleFromApi(accessToken, semesterId);
      } else {
        // No cache and no token - show error
        _errorMessage = 'Không có dữ liệu. Vui lòng kết nối internet.';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      // Check if this is a 401 error (token expired)
      final is401Error = e.toString().contains('401');
      print('[DEBUG] fetchExamSchedule ERROR: is401=$is401Error, error=$e');
      
      if (is401Error) {
        print('[DEBUG] fetchExamSchedule: 401 error, checking cache fallback');
        // Token expired - try to use cache as fallback
        final hasCache = await _dbHelper.hasRegisterPeriodsCache(semesterId);
        print('[DEBUG] fetchExamSchedule: Cache fallback hasCache=$hasCache');
        
        if (hasCache) {
          // Load from cache instead of showing error
          _registerPeriods = await _dbHelper.getRegisterPeriods(semesterId);
          _registerPeriods.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          
          if (_registerPeriods.isNotEmpty && _selectedRegisterPeriodId == null) {
            _selectedRegisterPeriodId = _registerPeriods.first.id;
          }
          
          _isLoading = false;
          _errorMessage = null; // No error - we have cached data!
          notifyListeners();
          print('[DEBUG] fetchExamSchedule: SUCCESS using cache fallback');
          return; // Success! Using cached data
        }
        // No cache available - show friendly message
        print('[DEBUG] fetchExamSchedule: No cache available, showing error');
        _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      } else {
        // Other error - show actual error
        _errorMessage = e.toString();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch exam schedule from API and cache it
  Future<void> _fetchExamScheduleFromApi(
    String accessToken,
    int semesterId,
  ) async {
    try {
      final periods = await _authService.getRegisterPeriods(
        accessToken,
        semesterId,
      );

      _registerPeriods = periods;

      // Sort by display order
      _registerPeriods.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Auto-select the first period if none selected
      if (_registerPeriods.isNotEmpty && _selectedRegisterPeriodId == null) {
        _selectedRegisterPeriodId = _registerPeriods.first.id;
      }

      // Save to cache
      await _dbHelper.saveRegisterPeriods(semesterId, _registerPeriods);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[DEBUG] _fetchExamScheduleFromApi ERROR: $e');
      // Check if this is a 401 error (token expired) - completely silent
      final is401Error = e.toString().contains('401');
      
      // Check if this is an initial fetch (no existing periods) or background refresh
      if (_registerPeriods.isEmpty && _selectedSemesterId == semesterId) {
        // Initial fetch failed, rethrow so outer catch can handle with fallback
        print('[DEBUG] _fetchExamScheduleFromApi: Initial fetch failed, rethrowing');
        rethrow;
      } else if (!is401Error) {
        // Only log non-auth errors for background refresh
        print('Background exam schedule refresh failed: $e');
      }
      // If it's 401 and we have cached data, completely silent (expected offline behavior)
    }
  }

  /// Select a register period by ID and fetch exam rooms
  Future<void> selectRegisterPeriod(
    String? accessToken,
    int semesterId,
    int periodId,
    int examRound,
  ) async {
    _selectedRegisterPeriodId = periodId;
    _examRooms = []; // Clear exam rooms when register period changes
    _isLoadingRooms = true; // Show loading state immediately
    notifyListeners();
    
    // Fetch exam rooms for the selected register period and exam round
    await fetchExamRoomDetails(
      accessToken,
      semesterId,
      periodId,
      examRound,
    );
    
    // Pre-cache other exam rounds for this period in background
    if (accessToken != null) {
      _preCacheExamRounds(accessToken, semesterId, periodId, examRound);
    }
  }

  /// Select exam round (1, 2, etc.)
  void selectExamRound(int round) {
    _selectedExamRound = round;
    // Don't clear exam rooms here - let fetchExamRoomDetails handle it
    // This prevents showing "No exam schedule" briefly before loading
    notifyListeners();
  }

  /// Fetch exam room details for selected semester, register period, and exam round
  Future<void> fetchExamRoomDetails(
    String? accessToken,
    int semesterId,
    int registerPeriodId,
    int examRound,
  ) async {
    print('[DEBUG] fetchExamRoomDetails: semesterId=$semesterId, periodId=$registerPeriodId, round=$examRound');
    print('[DEBUG] fetchExamRoomDetails: accessToken=${accessToken?.substring(0, 20)}...');
    // Clear exam rooms when starting to fetch new data
    _examRooms = [];
    _isLoadingRooms = true;
    _roomErrorMessage = null;
    notifyListeners();

    try {
      // Try to load from cache first
      final hasCache = await _dbHelper.hasExamRoomCache(
        semesterId,
        registerPeriodId,
        examRound,
      );
      print('[DEBUG] fetchExamRoomDetails: hasCache=$hasCache');

      if (hasCache) {
        _examRooms = await _dbHelper.getExamRooms(
          semesterId,
          registerPeriodId,
          examRound,
        );

        _isLoadingRooms = false;
        notifyListeners();
        print('[DEBUG] fetchExamRoomDetails: Loaded ${_examRooms.length} rooms from cache');

        // Schedule notifications for cached data
        await _scheduleExamNotifications();

        // Fetch fresh data in background ONLY if we have a valid access token
        if (accessToken != null && accessToken.isNotEmpty) {
          print('[DEBUG] fetchExamRoomDetails: Starting background refresh');
          _fetchExamRoomDetailsFromApi(
            accessToken,
            semesterId,
            registerPeriodId,
            examRound,
          );
        }
        return;
      }

      // No cache, try to fetch from API if we have access token
      print('[DEBUG] fetchExamRoomDetails: No cache, trying API');
      if (accessToken != null && accessToken.isNotEmpty) {
        await _fetchExamRoomDetailsFromApi(
          accessToken,
          semesterId,
          registerPeriodId,
          examRound,
        );
      } else {
        // No cache and no token - show error
        _roomErrorMessage = 'Không có dữ liệu. Vui lòng kết nối internet.';
        _isLoadingRooms = false;
        notifyListeners();
      }
    } catch (e) {
      // Check if this is a 401 error (token expired)
      final is401Error = e.toString().contains('401');
      print('[DEBUG] fetchExamRoomDetails ERROR: is401=$is401Error, error=$e');
      
      if (is401Error) {
        print('[DEBUG] fetchExamRoomDetails: 401 error, checking cache fallback');
        // Token expired - try to use cache as fallback
        final hasCache = await _dbHelper.hasExamRoomCache(
          semesterId,
          registerPeriodId,
          examRound,
        );
        print('[DEBUG] fetchExamRoomDetails: Cache fallback hasCache=$hasCache');
        
        if (hasCache) {
          // Load from cache instead of showing error
          _examRooms = await _dbHelper.getExamRooms(
            semesterId,
            registerPeriodId,
            examRound,
          );
          
          _isLoadingRooms = false;
          _roomErrorMessage = null; // No error - we have cached data!
          notifyListeners();
          
          // Schedule notifications for cached data
          await _scheduleExamNotifications();
          print('[DEBUG] fetchExamRoomDetails: SUCCESS using cache fallback');
          return; // Success! Using cached data
        }
        // No cache available - show friendly message
        print('[DEBUG] fetchExamRoomDetails: No cache available, showing error');
        _roomErrorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      } else {
        // Other error - show actual error
        _roomErrorMessage = e.toString();
      }
      _isLoadingRooms = false;
      notifyListeners();
    }
  }

  /// Fetch exam room details from API and cache it
  Future<void> _fetchExamRoomDetailsFromApi(
    String accessToken,
    int semesterId,
    int registerPeriodId,
    int examRound,
  ) async {
    try {
      final rooms = await _authService.getStudentExamRooms(
        accessToken,
        semesterId,
        registerPeriodId,
        examRound,
      );

      // CRITICAL: Only update UI if the parameters still match current selection
      // This prevents background fetches from overwriting data when user has changed selection
      if (_selectedSemesterId == semesterId &&
          _selectedRegisterPeriodId == registerPeriodId &&
          _selectedExamRound == examRound) {
        // Sort rooms by exam date to maintain consistent order
        rooms.sort((a, b) {
          // First compare by exam date (if available)
          final aDate = a.examRoom?.examDate;
          final bDate = b.examRoom?.examDate;
          
          if (aDate != null && bDate != null) {
            final dateComparison = aDate.compareTo(bDate);
            if (dateComparison != 0) return dateComparison;
          } else if (aDate != null) {
            return -1; // a has date, b doesn't -> a comes first
          } else if (bDate != null) {
            return 1; // b has date, a doesn't -> b comes first
          }
          
          // If dates are equal or both null, compare by exam date string
          final aDateStr = a.examRoom?.examDateString ?? '';
          final bDateStr = b.examRoom?.examDateString ?? '';
          final dateStrComparison = aDateStr.compareTo(bDateStr);
          if (dateStrComparison != 0) return dateStrComparison;
          
          // If still equal, compare by subject name for stability
          return a.subjectName.compareTo(b.subjectName);
        });
        
        // Check if data actually changed before updating
        final dataChanged = _examRooms.length != rooms.length ||
            !_areExamRoomsEqual(_examRooms, rooms);
        
        _examRooms = rooms;
        _isLoadingRooms = false;
        notifyListeners();

        // Only re-schedule notifications if data actually changed
        if (dataChanged) {
          await _scheduleExamNotifications();
        }
      }

      // Always save to cache regardless of current selection
      await _dbHelper.saveExamRooms(
        semesterId,
        registerPeriodId,
        examRound,
        rooms, // Save the fetched data, not _examRooms
      );
    } catch (e) {
      print('[DEBUG] _fetchExamRoomDetailsFromApi ERROR: $e');
      // Check if this is a 401 error (token expired) - completely silent
      final is401Error = e.toString().contains('401');
      
      // Silently fail background refresh if we already have cached data
      if (_examRooms.isEmpty &&
          _selectedSemesterId == semesterId &&
          _selectedRegisterPeriodId == registerPeriodId &&
          _selectedExamRound == examRound) {
        // This is initial fetch (not background), rethrow so outer catch can handle with fallback
        print('[DEBUG] _fetchExamRoomDetailsFromApi: Initial fetch failed, rethrowing');
        rethrow; // Let outer catch handle it with cache fallback!
      } else if (!is401Error) {
        // Background refresh failed for non-auth reasons - log it
        print('Background exam room refresh failed: $e');
      }
      // If it's 401 and we have cached data, completely silent (expected offline behavior)
    }
  }

  /// Clear all data
  void clear() {
    _registerPeriods = [];
    _examRooms = [];
    _selectedRegisterPeriodId = null;
    _selectedSemesterId = null;
    _selectedExamRound = 1;
    _errorMessage = null;
    _roomErrorMessage = null;
    _isLoading = false;
    _isLoadingRooms = false;
    notifyListeners();
  }

  /// Schedule notifications for upcoming exams
  Future<void> _scheduleExamNotifications() async {
    if (_examRooms.isEmpty) return;

    try {
      await NotificationHelper.scheduleExamNotifications(
        examRooms: _examRooms,
      );
      print('✅ Notifications scheduled for ${_examRooms.length} exams');
    } catch (e) {
      print('⚠️ Failed to schedule exam notifications: $e');
    }
  }

  /// Compare two lists of exam rooms for equality
  bool _areExamRoomsEqual(List<StudentExamRoom> list1, List<StudentExamRoom> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      final room1 = list1[i];
      final room2 = list2[i];
      
      // Compare key fields that would affect notifications
      if (room1.id != room2.id ||
          room1.subjectName != room2.subjectName ||
          room1.examCode != room2.examCode ||
          room1.examRoom?.examDate != room2.examRoom?.examDate ||
          room1.examRoom?.examHour?.id != room2.examRoom?.examHour?.id) {
        return false;
      }
    }
    
    return true;
  }
}
