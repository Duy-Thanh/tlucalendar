import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tlucalendar/providers/theme_provider.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/providers/settings_provider.dart';

import 'package:tlucalendar/theme/app_theme.dart';
import 'package:tlucalendar/screens/app_initializer.dart';
import 'package:tlucalendar/injection_container.dart' as di;

import 'package:tlucalendar/services/daily_notification_service.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Service Locator (Dependency Injection)
  await di.init();

  // Initialize date formatting
  await initializeDateFormatting('vi', null);

  // Initialize timezone database
  tz.initializeTimeZones();

  // Initialize Daily Notification Service
  await DailyNotificationService.initialize();
  await DailyNotificationService.requestPermissions();

  // Load saved settings for notification time
  final prefs = await SharedPreferences.getInstance();
  final notifEnabled = prefs.getBool('setting_daily_notif') ?? true;
  final notifHour = prefs.getInt('setting_daily_notif_hour') ?? 7;
  final notifMinute = prefs.getInt('setting_daily_notif_minute') ?? 0;

  if (notifEnabled) {
    await DailyNotificationService.scheduleDailyCheck(
      hour: notifHour,
      minute: notifMinute,
    );
  } else {
    // Ensure cancellation if disabled
    await DailyNotificationService.cancelDailyCheck();
  }

  // Initialize Auto Refresh Service
  await AutoRefreshService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()..init()),
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ScheduleProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ExamProvider>()),
        ChangeNotifierProvider(
          create: (_) => di.sl<SettingsProvider>()..init(),
        ),
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
          title: 'TLU Calendar',
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
