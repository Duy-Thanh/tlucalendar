import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:tlucalendar/providers/theme_provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/screens/login_screen.dart';
import 'package:tlucalendar/utils/error_logger.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          elevation: 0,
          title: Text(
                'Cài đặt',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
        ),
        SliverToBoxAdapter(
          child: Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              final user = userProvider.currentUser;
              // Only show profile card when logged in
              if (!userProvider.isLoggedIn) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.studentId,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Tài khoản',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (userProvider.isLoggedIn) ...[
                        ListTile(
                          leading: const Icon(Icons.check_circle),
                          title: const Text('Đã đăng nhập'),
                          subtitle: Text(userProvider.currentUser.studentId),
                          trailing: Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              userProvider.logout();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Đã đăng xuất'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Text('Đăng xuất'),
                          ),
                        ),
                      ] else ...[
                        ListTile(
                          leading: const Icon(Icons.lock_outlined),
                          title: const Text('Chưa đăng nhập'),
                          subtitle: const Text('Nhấp để đăng nhập tài khoản'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            child: const Text('Đăng nhập'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Hiển thị',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            themeProvider.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            themeProvider.isDarkMode
                                ? 'Chế độ tối'
                                : 'Chế độ sáng',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Thông tin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Phiên bản ứng dụng',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '2025.10.27',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nhà phát triển',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Nguyen Duy Thanh',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Báo lỗi'),
                subtitle: const Text('Gửi báo cáo lỗi kèm thông tin thiết bị'),
                onTap: () async {
                  await _sendBugReport(context);
                },
              ),
            ),
          ),
        ),
        // Only show Third-party notices on Android and iOS
        if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Thông báo bên thứ ba'),
                  subtitle: const Text('Thông báo giấy phép của bên thứ ba'),
                  onTap: () async {
                    await _viewThirdPartyNotices(context);
                  },
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  static Future<void> _sendBugReport(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Gather app info
    String appName = 'TLU Calendar';
    String appVersion = '2025.10.26';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appName = pkg.appName;
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (e) {
      // ignore
    }

    // Gather device info
    final deviceInfo = DeviceInfoPlugin();
    String deviceDetails = '';
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceDetails = 'Android ${info.version.release} (SDK ${info.version.sdkInt}) - ${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceDetails = 'iOS ${info.systemVersion} - ${info.name} ${info.model}';
      } else {
        deviceDetails = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } catch (e) {
      deviceDetails = 'Unknown device info: $e';
    }

    // Collect user and app state
    final userId = userProvider.isLoggedIn ? userProvider.currentUser.studentId : 'not_logged_in';
    final userName = userProvider.isLoggedIn ? userProvider.currentUser.fullName : 'not_logged_in';
    final selectedSemester = userProvider.selectedSemester?.semesterName ?? 'unknown';

    // Get error logs from ErrorLogger
    final errorLogger = ErrorLogger();
    final errorLogs = errorLogger.getFormattedErrors();
    final errorCount = errorLogger.getRecentErrors().length;

    final subject = 'TLU Calendar Bug Report';

    final body = StringBuffer();
    body.writeln('App: $appName');
    body.writeln('Version: $appVersion');
    body.writeln('Device: $deviceDetails');
    body.writeln('User: $userName ($userId)');
    body.writeln('Selected semester: $selectedSemester');
    body.writeln('Errors logged this session: $errorCount');
    body.writeln('\n--- INSTRUCTIONS ---');
    body.writeln('Please describe the issue below:');
    body.writeln('1. What were you doing when the error occurred?');
    body.writeln('2. What did you expect to happen?');
    body.writeln('3. What actually happened?');
    body.writeln('4. Can you reproduce this issue? If yes, describe the steps.');
    body.writeln('\n--- YOUR DESCRIPTION HERE ---\n\n\n');
    body.writeln('\n--- DEBUG INFO (do not edit below) ---');
    body.writeln('\n=== ERROR HISTORY ===');
    body.writeln(errorLogs);
    body.writeln('\nReport generated at: ${DateTime.now()}');

    // Use percent-encoding for subject/body so spaces are encoded as %20
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body.toString());
    final mailto = 'mailto:thanhdz167@gmail.com?subject=$encodedSubject&body=$encodedBody';
    final uri = Uri.parse(mailto);

    try {
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở ứng dụng email trên thiết bị này.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi mở email: $e')),
      );
    }
  }

  static const MethodChannel _navigationChannel = 
      MethodChannel('com.nekkochan.tlucalendar/navigation');

  static Future<void> _viewThirdPartyNotices(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Launch the activity securely via method channel
        final result = await _navigationChannel.invokeMethod('openLicenseActivity');
        if (result != true) {
          throw Exception('Failed to open license activity');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể mở màn hình giấy phép: $e')),
          );
        }
        debugPrint("⚠️ Cannot launch LicenseActivity: $e");
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Use Flutter's built-in LicensePage for iOS
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Theme(
            data: Theme.of(context),
            child: const LicensePage(
              applicationName: 'TLU Calendar',
              applicationVersion: '2025.10.27',
            ),
          ),
        ),
      );
    }
  }
}
