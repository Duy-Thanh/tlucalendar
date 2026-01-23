import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class CrashpadService {
  static const MethodChannel _channel = MethodChannel(
    'com.nekkochan.tlucalendar/crashpad',
  );

  /// Initialize Crashpad.
  /// [uploadUrl] is the URL where minidumps will be uploaded. The native side
  /// will also write dumps to the app's cache directory.
  static Future<void> initialize({required String uploadUrl}) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final bool success = await _channel.invokeMethod('initialize', {
          'url': uploadUrl,
        });
        if (success) {
          debugPrint('Crashpad initialized successfully');
        } else {
          debugPrint('Crashpad initialization returned false');
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to initialize Crashpad: '${e.message}'.");
    }
  }
}
