import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:tlucalendar/screens/today_screen.dart';
import 'package:tlucalendar/screens/calendar_screen.dart';
import 'package:tlucalendar/screens/exam_schedule_screen.dart';
import 'package:tlucalendar/screens/settings_screen.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';
import 'package:tlucalendar/providers/auth_provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _selectedIndex = 0;
  Timer? _refreshCheckTimer;
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;

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

    // Initialize animation controllers for each tab
    _animationControllers = List.generate(
      4,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    // Initialize scale animations
    _scaleAnimations = _animationControllers.map((controller) {
      return Tween<double>(
        begin: 1.0,
        end: 1.15,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));
    }).toList();

    // Start periodic check every 10 seconds when app is in foreground
    _startRefreshCheckTimer();
  }

  @override
  void dispose() {
    _refreshCheckTimer?.cancel();
    for (var controller in _animationControllers) {
      controller.dispose();
    }
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
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.init();

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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Use IndexedStack to preserve state of each tab so screens aren't
      // recreated when switching tabs. This prevents re-running initState
      // (and thus avoids unnecessary API calls) when returning to a tab.
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : colorScheme.shadow.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
                if (isDark)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  HapticFeedback.lightImpact(); // Add haptic feedback
                  // Animate the tapped icon
                  _animationControllers[index].forward().then((_) {
                    _animationControllers[index].reverse();
                  });

                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: [
                  NavigationDestination(
                    icon: ScaleTransition(
                      scale: _scaleAnimations[0],
                      child: const Icon(Icons.today),
                    ),
                    label: 'Hôm nay',
                  ),
                  NavigationDestination(
                    icon: ScaleTransition(
                      scale: _scaleAnimations[1],
                      child: const Icon(Icons.calendar_month),
                    ),
                    label: 'Lịch học',
                  ),
                  NavigationDestination(
                    icon: ScaleTransition(
                      scale: _scaleAnimations[2],
                      child: const Icon(Icons.quiz),
                    ),
                    label: 'Lịch thi',
                  ),
                  NavigationDestination(
                    icon: ScaleTransition(
                      scale: _scaleAnimations[3],
                      child: const Icon(Icons.settings),
                    ),
                    label: 'Cài đặt',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Auto-resume happens in background, no button needed
      // floatingActionButton: const ResumeCachingButton(),
    );
  }
}
