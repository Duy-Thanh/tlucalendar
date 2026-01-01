import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupService {
  // Singleton pattern if needed, but static methods or simple instance is fine.
  // Using static for simplicity as it relies on other singletons.

  /// Exports the current database to a file and shares it.
  /// Returns null on success, or error message string on failure.
  static Future<String?> exportDatabase() async {
    try {
      final dbHelper = DatabaseHelper.instance;

      // 1. Get current DB path
      final dbPath = await dbHelper.databasePath;
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return "Không tìm thấy dữ liệu để sao lưu.";
      }

      // 2. Determine consistent backup location (Downloads/Documents)
      Directory? backupDir;
      String? savedPath;

      if (Platform.isAndroid) {
        // Request storage permission for older Androids
        // For Android 13+, Permission.storage is invalid for images/videos but okay for files via ManageExternalStorage?
        // Actually, simple file write to publicly accessible Downloads often works without dangerous permissions on modern Android
        // IF we use SAF or just standard paths if not scoped.
        // But to be safe, we request it.
        var status = await Permission.storage.status;
        if (status.isGranted) {
          status = await Permission.storage.request();
        }

        // Try standard Download path
        // Note: getExternalStoragePublicDirectory is deprecated but mostly functional or replaced by direct path construction
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          backupDir = Directory(join(downloadDir.path, 'TLUCalendar_Backups'));
        } else {
          // Fallback to app external
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            backupDir = Directory(join(extDir.path, 'backups'));
          }
        }
      } else {
        // iOS: Use Documents directory
        final docDir = await getApplicationDocumentsDirectory();
        backupDir = Directory(join(docDir.path, 'Backups'));
      }

      if (backupDir == null) {
        return "Không thể xác định thư mục lưu trữ.";
      }

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = "tlucalendar_backup_$nowStr.db";
      final backupPath = join(backupDir.path, backupFileName);

      // 3. Close DB -> Copy -> Reopen
      await dbHelper.close();
      try {
        await dbFile.copy(backupPath);
        savedPath = backupPath;
      } catch (e) {
        // Fallback if permission denied to Download folder
        debugPrint("Failed to save to $backupPath: $e");
        if (Platform.isAndroid) {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final fallbackDir = Directory(join(extDir.path, 'backups'));
            if (!await fallbackDir.exists())
              await fallbackDir.create(recursive: true);
            final fallbackPath = join(fallbackDir.path, backupFileName);
            await dbFile.copy(fallbackPath);
            savedPath = fallbackPath;
          }
        }
        if (savedPath == null) rethrow;
      }
      await dbHelper.ensureInitialized();

      // 4. Share the file
      final xFile = XFile(savedPath!);
      await Share.shareXFiles([
        xFile,
      ], text: 'Backup dữ liệu TLU Calendar ($nowStr)');

      return "Đã lưu backup tại: $savedPath";
    } catch (e) {
      debugPrint("Export Error: $e");
      return "Lỗi sao lưu: $e";
    }
  }

  /// Restores the database from a selected file.
  /// Returns null on success, or error message string on failure.
  static Future<String?> importDatabase() async {
    try {
      // 1. Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Android sometimes hides .db extensions if we use custom type
        // allowedExtensions: ['db'], // Can be stricter if needed
      );

      if (result == null || result.files.isEmpty) {
        return "Đã hủy chọn file.";
      }

      final file = result.files.single;
      final inputPath = file.path; // Available on mobile

      if (inputPath == null) {
        return "Không thể đọc file này (Path null).";
      }

      // Basic validation (extension or magic bytes)
      if (!inputPath.endsWith('.db') && !file.name.endsWith('.db')) {
        return "File không đúng định dạng .db";
      }

      // 2. Validate SQLite header?
      // Optional but good. "SQLite format 3"
      final inputFile = File(inputPath);
      final header = await inputFile.openRead(0, 16).first;
      final headerStr = String.fromCharCodes(header);
      if (!headerStr.startsWith('SQLite format 3')) {
        return "File này không phải là database SQLite hợp lệ.";
      }

      final dbHelper = DatabaseHelper.instance;
      final dbPath = await dbHelper.databasePath;

      // 3. Close current DB
      await dbHelper.close();

      // 4. Overwrite
      // Delete existing .db, .wal, .shm
      final dbFile = File(dbPath);
      final walFile = File("$dbPath-wal");
      final shmFile = File("$dbPath-shm");

      if (await dbFile.exists()) await dbFile.delete();
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      await inputFile.copy(dbPath);

      // 5. Re-open to verify
      await dbHelper.ensureInitialized();

      return null; // Success
    } catch (e) {
      debugPrint("Import Error: $e");
      // Try to re-open if failed mid-way so app doesn't crash
      try {
        await DatabaseHelper.instance.ensureInitialized();
      } catch (_) {}
      return "Lỗi khôi phục: $e";
    }
  }
}
