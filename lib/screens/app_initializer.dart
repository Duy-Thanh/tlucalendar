import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/screens/home_shell.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Initialize AuthProvider (load token)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.init();

    // If logged in, initialize ScheduleProvider
    if (authProvider.isLoggedIn && authProvider.accessToken != null) {
      final scheduleProvider = Provider.of<ScheduleProvider>(
        context,
        listen: false,
      );
      if (mounted) scheduleProvider.init(authProvider.accessToken!);

      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      if (mounted) examProvider.init(authProvider.accessToken!);
    }

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Splash Screen
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // HomeShell handles auth state display, so just go there.
    return const HomeShell();
  }
}
