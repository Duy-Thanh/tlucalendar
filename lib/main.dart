import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:tlucalendar/providers/theme_provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/services/notification_service.dart';
import 'package:tlucalendar/services/daily_notification_service.dart';
import 'package:tlucalendar/services/download_foreground_service.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';
import 'package:tlucalendar/theme/app_theme.dart';
import 'package:tlucalendar/screens/home_shell.dart';
import 'package:tlucalendar/utils/error_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone database for iOS scheduled notifications
  tz.initializeTimeZones();
  
  // Initialize foreground service for background downloads
  DownloadForegroundService.initForegroundTask();
  
  // Initialize auto-refresh service for daily data updates
  await AutoRefreshService.initialize();

  final errorLogger = ErrorLogger();

  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    errorLogger.logError(
      details.exception,
      details.stack,
      context: 'Flutter Framework Error',
    );
    debugPrint('🔴 Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Capture async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    errorLogger.logError(error, stack, context: 'Async Error');
    debugPrint('🔴 Async Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final userProvider = UserProvider();
  await userProvider.init();

  final examProvider = ExamProvider();
  
  // Link providers so UserProvider can fetch exam data during login
  userProvider.setExamProvider(examProvider);

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  debugPrint('✅ Notification service initialized');
  
  // Initialize daily notification background worker
  await DailyNotificationService.initialize();
  debugPrint('✅ Daily notification service initialized');
  
  // Schedule daily check if user has enabled it
  if (userProvider.dailyNotificationsEnabled) {
    await DailyNotificationService.scheduleDailyCheck();
    debugPrint('✅ Daily notification check scheduled');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider.value(value: examProvider),
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
          home: const HomeShell(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
