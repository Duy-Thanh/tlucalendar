import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';

import 'package:tlucalendar/providers/theme_provider.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';

import 'package:tlucalendar/theme/app_theme.dart';
import 'package:tlucalendar/screens/home_shell.dart';
// Ensure this exists or use home_shell logic
import 'package:tlucalendar/injection_container.dart' as di;

// Legacy services - keeping imports if they are standalone, otherwise commenting out usage if broken
// import 'package:tlucalendar/services/download_foreground_service.dart';
// import 'package:tlucalendar/services/auto_refresh_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Service Locator (Dependency Injection)
  await di.init();

  // Initialize date formatting
  await initializeDateFormatting('vi', null);

  // Initialize timezone database
  tz.initializeTimeZones();

  // Non-blocking background services init (if safe)
  // DownloadForegroundService.initForegroundTask();
  // AutoRefreshService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()..init()),
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ScheduleProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ExamProvider>()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'TLU Schedule',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AppInitializer(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

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
      // Fire and forget or await?
      // Better to await to avoid empty screen flash, or just fire.
      // Given Clean usage, we might want to just let HomeShell load data.
      // But init(accessToken) is needed.
      scheduleProvider.init(authProvider.accessToken!);

      // Similarly for ExamProvider if needed, or let screens handle it.
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      examProvider.init(authProvider.accessToken!);
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

    // Redirect logic
    // HomeShell handles auth state display, so just go there.
    return const HomeShell();
  }
}
