import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:tlucalendar/providers/theme_provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/screens/login_screen.dart';
import 'package:tlucalendar/screens/logs_screen.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';
import 'package:tlucalendar/utils/error_logger.dart';
// import 'package:tlucalendar/services/daily_notification_service.dart'; // Commented out with test button

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              'Thông báo',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      userProvider.notificationsEnabled
                                          ? Icons.notifications_active
                                          : Icons.notifications_off,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Thông báo lịch học',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 40),
                                  child: Text(
                                    'Nhận thông báo trước giờ học và thi',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: userProvider.notificationsEnabled,
                            onChanged: (value) async {
                              // ✅ ALWAYS check current permission status before toggling
                              // This handles the case where user granted permission in settings
                              await userProvider.checkNotificationPermission();
                              
                              // Try to toggle
                              bool success = await userProvider.toggleNotifications(value);
                              
                              if (context.mounted) {
                                if (value && !success) {
                                  // User tried to enable but permission denied
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '⚠️ Không thể bật thông báo - cần cấp quyền',
                                      ),
                                      duration: const Duration(seconds: 3),
                                      action: SnackBarAction(
                                        label: 'Cài đặt',
                                        onPressed: () async {
                                          try {
                                            if (Platform.isAndroid) {
                                              final PackageInfo packageInfo = await PackageInfo.fromPlatform();
                                              final String packageName = packageInfo.packageName;
                                              
                                              final AndroidIntent intent = AndroidIntent(
                                                action: 'android.settings.APP_NOTIFICATION_SETTINGS',
                                                arguments: <String, dynamic>{
                                                  'android.provider.extra.APP_PACKAGE': packageName,
                                                },
                                              );
                                              
                                              await intent.launch();
                                            } else if (Platform.isIOS) {
                                              final Uri settingsUri = Uri.parse('app-settings:');
                                              await launchUrl(settingsUri);
                                            }
                                          } catch (e) {
                                            LogService().log('Error opening settings: $e', level: LogLevel.error);
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                } else if (success) {
                                  // Only show success message if toggle actually changed
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? '✅ Đã bật thông báo'
                                            : 'Đã tắt thông báo',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      // Show warning ONLY when toggle is OFF but permission is denied
                      // (so user knows they need to grant permission before enabling)
                      if (!userProvider.notificationsEnabled && 
                          !userProvider.hasNotificationPermission) ...[
                        const Divider(height: 16),
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.warning,
                            color: Colors.orange,
                          ),
                          title: Text(
                            'Cần cấp quyền thông báo',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Vui lòng cấp quyền thông báo trong cài đặt hệ thống để nhận thông báo',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              try {
                                if (Platform.isAndroid) {
                                  // Android: Open app notification settings using AndroidIntent
                                  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
                                  final String packageName = packageInfo.packageName;
                                  
                                  final AndroidIntent intent = AndroidIntent(
                                    action: 'android.settings.APP_NOTIFICATION_SETTINGS',
                                    arguments: <String, dynamic>{
                                      'android.provider.extra.APP_PACKAGE': packageName,
                                    },
                                  );
                                  
                                  await intent.launch();
                                } else if (Platform.isIOS) {
                                  // iOS: Open app settings
                                  final Uri settingsUri = Uri.parse('app-settings:');
                                  await launchUrl(settingsUri);
                                }
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã mở cài đặt - Vui lòng bật Thông báo'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi: $e'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.settings),
                            label: Text('Mở cài đặt hệ thống'),
                          ),
                        ),
                      ],
                      // Daily notification toggle
                      if (userProvider.notificationsEnabled) ...[
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.wb_sunny),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Nhắc nhở hàng ngày',
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 40),
                                    child: Text(
                                      'Nhận thông báo tóm tắt lịch học và thi mỗi sáng (7:00 AM)',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: userProvider.dailyNotificationsEnabled,
                              onChanged: (value) async {
                                await userProvider.toggleDailyNotifications(value);
                              
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? '✅ Đã bật nhắc nhở hàng ngày (7:00 AM)'
                                            : 'Đã tắt nhắc nhở hàng ngày',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Auto-refresh status section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Cập nhật tự động',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              if (!userProvider.isLoggedIn) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tính năng tự động cập nhật chỉ hoạt động sau khi bạn đã đăng nhập thành công',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tự động cập nhật dữ liệu',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hệ thống sẽ tự động tải dữ liệu mới mỗi ngày (8 AM - 12 PM) để đảm bảo thông tin luôn chính xác',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<DateTime?>(
                        future: AutoRefreshService.getNextRefreshTime(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final nextTime = snapshot.data!;
                            final timeStr = '${nextTime.day}/${nextTime.month} ${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Lần cập nhật tiếp theo: $timeStr',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<DateTime?>(
                        future: AutoRefreshService.getLastRefreshTime(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final lastTime = snapshot.data!;
                            final now = DateTime.now();
                            final diff = now.difference(lastTime);
                            
                            // Format last update time
                            final timeStr = '${lastTime.day}/${lastTime.month}/${lastTime.year} ${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}';
                            
                            String timeAgo;
                            if (diff.inMinutes < 60) {
                              timeAgo = '${diff.inMinutes} phút trước';
                            } else if (diff.inHours < 24) {
                              timeAgo = '${diff.inHours} giờ trước';
                            } else {
                              timeAgo = '${diff.inDays} ngày trước';
                            }
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Thời gian cập nhật dữ liệu:',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 22),
                                  child: Text(
                                    '$timeStr ($timeAgo)',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
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
              'Hiển thị',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                        '2025.11.15',
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
                        'Commit',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        // 24 characters only
                        'd3550956373eb808164fb5ab',
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
                        'Build type',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'release',
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
                        'Build branch',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'release_2025.11.15_XX-XX',
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mã hóa dữ liệu',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Text(
                        'AES-256',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
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
                leading: const Icon(Icons.receipt_long),
                title: const Text('System Logs'),
                subtitle: const Text('Xem nhật ký hệ thống'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LogsScreen(),
                    ),
                  );
                },
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
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)
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
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  static Future<void> _sendBugReport(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Gather app info
    String appName = 'TLU Calendar';
    String appVersion = '2025.11.15';
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
        deviceDetails =
            'Android ${info.version.release} (SDK ${info.version.sdkInt}) - ${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceDetails =
            'iOS ${info.systemVersion} - ${info.name} ${info.model}';
      } else {
        deviceDetails =
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } catch (e) {
      deviceDetails = 'Unknown device info: $e';
    }

    // Collect user and app state
    final userId = userProvider.isLoggedIn
        ? userProvider.currentUser.studentId
        : 'not_logged_in';
    final userName = userProvider.isLoggedIn
        ? userProvider.currentUser.fullName
        : 'not_logged_in';
    final selectedSemester =
        userProvider.selectedSemester?.semesterName ?? 'unknown';

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
    body.writeln(
      '4. Can you reproduce this issue? If yes, describe the steps.',
    );
    body.writeln('\n--- YOUR DESCRIPTION HERE ---\n\n\n');
    body.writeln('\n--- DEBUG INFO (do not edit below) ---');
    body.writeln('\n=== ERROR HISTORY ===');
    body.writeln(errorLogs);
    body.writeln('\nReport generated at: ${DateTime.now()}');

    // Use percent-encoding for subject/body so spaces are encoded as %20
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body.toString());
    final mailto =
        'mailto:thanhdz167@gmail.com?subject=$encodedSubject&body=$encodedBody';
    final uri = Uri.parse(mailto);

    try {
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng email trên thiết bị này.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi mở email: $e')));
    }
  }

  static const MethodChannel _navigationChannel = MethodChannel(
    'com.nekkochan.tlucalendar/navigation',
  );

  static Future<void> _viewThirdPartyNotices(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Launch the activity securely via method channel
        final result = await _navigationChannel.invokeMethod(
          'openLicenseActivity',
        );
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
              applicationVersion: '2025.11.15',
            ),
          ),
        ),
      );
    }
  }
}
