import 'package:flutter/material.dart';
import 'package:tlucalendar/screens/today_screen.dart';
import 'package:tlucalendar/screens/calendar_screen.dart';
import 'package:tlucalendar/screens/exam_schedule_screen.dart';
import 'package:tlucalendar/screens/settings_screen.dart';
import 'package:tlucalendar/widgets/cache_progress_banner.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const TodayScreen(),
    const CalendarScreen(),
    const ExamScheduleScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use IndexedStack to preserve state of each tab so screens aren't
      // recreated when switching tabs. This prevents re-running initState
      // (and thus avoids unnecessary API calls) when returning to a tab.
      body: Column(
        children: [
          // Cache progress banner at the top
          const CacheProgressBanner(),
          
          // Main content with tab screens
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
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
      floatingActionButton: const ResumeCachingButton(),
    );
  }
}
