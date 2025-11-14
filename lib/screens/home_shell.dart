import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:tlucalendar/screens/today_screen.dart';
import 'package:tlucalendar/screens/calendar_screen.dart';
import 'package:tlucalendar/screens/exam_schedule_screen.dart';
import 'package:tlucalendar/screens/settings_screen.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';
import 'package:tlucalendar/providers/user_provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _refreshCheckTimer;

  final List<Widget> _screens = [
    const TodayScreen(),
    const CalendarScreen(),
    const ExamScheduleScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDataRefresh(); // Check on first load
    
    // Start periodic check every 10 seconds when app is in foreground
    _startRefreshCheckTimer();
  }

  @override
  void dispose() {
    _refreshCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Start periodic timer to check for data refresh
  void _startRefreshCheckTimer() {
    _refreshCheckTimer?.cancel();
    _refreshCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _checkDataRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app resumes from background, check if data was refreshed
    if (state == AppLifecycleState.resumed) {
      _checkDataRefresh();
      _startRefreshCheckTimer(); // Restart timer when app resumes
    } else if (state == AppLifecycleState.paused) {
      _refreshCheckTimer?.cancel(); // Stop timer when app goes to background
    }
  }

  /// Check if data was refreshed and reload UI if needed
  Future<void> _checkDataRefresh() async {
    final isRefreshPending = await AutoRefreshService.isDataRefreshPending();
    
    if (isRefreshPending && mounted) {
      debugPrint('🔄 [HomeShell] Data refresh detected, reloading UI...');
      
      // Clear the pending flag first to prevent duplicate reloads
      await AutoRefreshService.clearDataRefreshPending();
      
      // Re-initialize user provider to reload all data from database
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.init();
        
        debugPrint('✅ [HomeShell] UI reloaded successfully');
        
        // Show a snackbar to inform user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📱 Dữ liệu đã được cập nhật tự động'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ [HomeShell] Failed to reload UI: $e');
        // Don't show error to user, data will reload on next check
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use IndexedStack to preserve state of each tab so screens aren't
      // recreated when switching tabs. This prevents re-running initState
      // (and thus avoids unnecessary API calls) when returning to a tab.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Hôm nay'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Lịch học',
          ),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Lịch thi'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
      // Auto-resume happens in background, no button needed
      // floatingActionButton: const ResumeCachingButton(),
    );
  }
}
