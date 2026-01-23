import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class CrashpadService {
  static const MethodChannel _channel = MethodChannel(
    'com.nekkochan.tlucalendar/crashpad',
  );

  static String? _uploadUrl;

  /// Initialize Crashpad.
  /// [uploadUrl] is the URL where minidumps will be uploaded. The native side
  /// will also write dumps to the app's cache directory.
  static Future<void> initialize({required String uploadUrl}) async {
    _uploadUrl = uploadUrl;
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

  /// Manually report a Dart exception to the server.
  static Future<void> sendDartException(Object error, StackTrace stack) async {
    if (_uploadUrl == null) return;

    try {
      final String report = "Dart Exception: $error\n\nStack Trace:\n$stack";
      final String filename =
          "dart_error_${DateTime.now().millisecondsSinceEpoch}.txt";

      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(report);

      await _uploadFile(file);

      // Cleanup
      await file.delete();
    } catch (e) {
      debugPrint("Failed to send Dart exception: $e");
    }
  }

  static Future<void> _uploadFile(File file) async {
    if (_uploadUrl == null) return;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
      request.files.add(
        await http.MultipartFile.fromPath(
          'upload_file_minidump', // Reusing the same field name as Crashpad
          file.path,
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        debugPrint("Dart exception uploaded successfully");
      } else {
        debugPrint("Failed to upload Dart exception: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error uploading file: $e");
    }
  }
}
