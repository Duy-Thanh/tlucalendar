import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/services/auto_refresh_service.dart';
import 'package:tlucalendar/services/daily_notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  // Keys
  static const String _keyAutoRefresh = 'setting_auto_refresh';
  static const String _keyDailyNotif = 'setting_daily_notif';
  static const String _keyDailyNotifHour = 'setting_daily_notif_hour';
  static const String _keyDailyNotifMinute = 'setting_daily_notif_minute';

  // State
  bool _autoRefreshEnabled = true;
  bool _dailyNotificationEnabled = true;
  TimeOfDay _dailyNotificationTime = const TimeOfDay(hour: 7, minute: 0);

  // Getters
  bool get autoRefreshEnabled => _autoRefreshEnabled;
  bool get dailyNotificationEnabled => _dailyNotificationEnabled;
  TimeOfDay get dailyNotificationTime => _dailyNotificationTime;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load saved settings (default to true/7:00)
    _autoRefreshEnabled = _prefs.getBool(_keyAutoRefresh) ?? true;
    _dailyNotificationEnabled = _prefs.getBool(_keyDailyNotif) ?? true;

    final h = _prefs.getInt(_keyDailyNotifHour) ?? 7;
    final m = _prefs.getInt(_keyDailyNotifMinute) ?? 0;
    _dailyNotificationTime = TimeOfDay(hour: h, minute: m);

    // Sync services with saved state (in case they were manually cancelled/changed externally)
    // We don't force re-schedule here to avoid alarm spam on every app start,
    // unless the services handle distinct checks efficiently.
    // Data sync services usually check if alarm exists, but here we just ensure state matches.
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool enabled) async {
    if (_autoRefreshEnabled == enabled) return;

    _autoRefreshEnabled = enabled;
    await _prefs.setBool(_keyAutoRefresh, enabled);
    notifyListeners();

    if (enabled) {
      await AutoRefreshService.schedulePeriodicRefresh();
    } else {
      await AutoRefreshService.cancelPeriodicRefresh();
    }
  }

  Future<void> setDailyNotification(bool enabled) async {
    if (_dailyNotificationEnabled == enabled) return;

    _dailyNotificationEnabled = enabled;
    await _prefs.setBool(_keyDailyNotif, enabled);
    notifyListeners();

    if (enabled) {
      await DailyNotificationService.scheduleDailyCheck(
        hour: _dailyNotificationTime.hour,
        minute: _dailyNotificationTime.minute,
      );
    } else {
      await DailyNotificationService.cancelDailyCheck();
    }
  }

  Future<void> setDailyNotificationTime(TimeOfDay time) async {
    if (_dailyNotificationTime == time) return;

    _dailyNotificationTime = time;
    await _prefs.setInt(_keyDailyNotifHour, time.hour);
    await _prefs.setInt(_keyDailyNotifMinute, time.minute);
    notifyListeners();

    if (_dailyNotificationEnabled) {
      // Re-schedule with new time
      await DailyNotificationService.cancelDailyCheck();
      await DailyNotificationService.scheduleDailyCheck(
        hour: time.hour,
        minute: time.minute,
      );
    }
  }
}
