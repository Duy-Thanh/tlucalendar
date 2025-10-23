import 'package:flutter/material.dart';
import 'package:tlucalendar/screens/today_screen.dart';
import 'package:tlucalendar/screens/calendar_screen.dart';
import 'package:tlucalendar/screens/settings_screen.dart';

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
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Lịch học',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
