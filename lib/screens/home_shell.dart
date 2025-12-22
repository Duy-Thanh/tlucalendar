import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tlucalendar/screens/today_screen.dart';
import 'package:tlucalendar/screens/calendar_screen.dart';
import 'package:tlucalendar/screens/exam_schedule_screen.dart';
import 'package:tlucalendar/screens/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  int _selectedIndex = 0;
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
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
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
    );
  }
}
