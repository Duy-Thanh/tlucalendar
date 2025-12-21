import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/core/parser/json_parser.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_remote_data_source.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_remote_data_source.dart';

/// Foreground service for downloading data in background
/// Runs in separate isolate and survives app exit
class DownloadForegroundService {
  static final _log = LogService();

  /// Initialize the foreground service
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'download_channel',
        channelName: 'Tải dữ liệu offline',
        channelDescription:
            'Đang tải dữ liệu lịch học và lịch thi để sử dụng offline',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        showWhen: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          2000,
        ), // Check progress every 2 seconds
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service with download data
  static Future<bool> startDownload({
    required String accessToken,
    required List<Map<String, dynamic>> semesters,
    required int currentSemesterId,
  }) async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      _log.log('[ForegroundService] Already running', level: LogLevel.warning);
      return true;
    }

    // Removed log

    // Save download data to SharedPreferences for isolate access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_access_token', accessToken);
    await prefs.setInt('download_current_semester_id', currentSemesterId);
    await prefs.setString(
      'download_semesters',
      semesters.map((s) => '${s['id']}|${s['name']}').join(','),
    );
    await prefs.setBool('download_in_progress', true);
    await prefs.setBool('download_complete', false);
    await prefs.setInt('download_total_semesters', semesters.length);
    await prefs.setInt('download_completed_semesters', 0);
    await prefs.setString('download_current_semester_name', '');

    await FlutterForegroundTask.startService(
      notificationTitle: 'Đang tải dữ liệu offline',
      notificationText: 'Bắt đầu tải ${semesters.length} học kỳ...',
      callback: startCallback,
    );

    return await FlutterForegroundTask.isRunningService;
  }

  /// Stop the foreground service
  static Future<bool> stopService() async {
    // Removed log
    await FlutterForegroundTask.stopService();
    return !(await FlutterForegroundTask.isRunningService);
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Get download progress
  static Future<Map<String, dynamic>> getProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'inProgress': prefs.getBool('download_in_progress') ?? false,
      'complete': prefs.getBool('download_complete') ?? false,
      'total': prefs.getInt('download_total_semesters') ?? 0,
      'completed': prefs.getInt('download_completed_semesters') ?? 0,
      'currentSemester':
          prefs.getString('download_current_semester_name') ?? '',
    };
  }
}

/// Callback for foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DownloadTaskHandler());
}

/// Task handler that performs actual downloads in isolate
class DownloadTaskHandler extends TaskHandler {
  int _totalSemesters = 0;
  int _completedSemesters = 0;
  bool _downloadComplete = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('[ForegroundService] Task started at $timestamp');

    // Start the download process (don't await - let it run in background)
    _startDownloadProcess()
        .then((_) {
          print('[ForegroundService] Download process completed');
        })
        .catchError((e) {
          print('[ForegroundService] Download process error: $e');
        });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Update notification with current progress from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSemesters = prefs.getInt('download_total_semesters') ?? 0;
      _completedSemesters = prefs.getInt('download_completed_semesters') ?? 0;
      final currentSemester =
          prefs.getString('download_current_semester_name') ?? '';
      final isComplete = prefs.getBool('download_complete') ?? false;

      if (isComplete && !_downloadComplete) {
        _downloadComplete = true;
        await FlutterForegroundTask.updateService(
          notificationTitle: '✅ Tải dữ liệu hoàn tất',
          notificationText: 'Đã tải xong $_totalSemesters học kỳ',
        );

        // Stop service after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        await FlutterForegroundTask.stopService();
      } else if (_totalSemesters > 0) {
        final percent = ((_completedSemesters / _totalSemesters) * 100).toInt();
        await FlutterForegroundTask.updateService(
          notificationTitle:
              'Đang tải dữ liệu offline ($_completedSemesters/$_totalSemesters)',
          notificationText: currentSemester.isNotEmpty
              ? '$currentSemester - $percent%'
              : 'Đang xử lý... $percent%',
        );
      }
    } catch (e) {
      print('[ForegroundService] Error updating notification: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool byUser) async {
    print('[ForegroundService] Task destroyed at $timestamp (byUser: $byUser)');

    if (byUser) {
      // User cancelled - mark as not in progress
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('download_in_progress', false);
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  /// Perform the actual download in background
  Future<void> _startDownloadProcess() async {
    print('[ForegroundService] _startDownloadProcess called');

    try {
      print('[ForegroundService] Reading SharedPreferences...');

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('download_access_token');
      final currentSemesterId = prefs.getInt('download_current_semester_id');
      final semestersStr = prefs.getString('download_semesters');

      print(
        '[ForegroundService] Access token: ${accessToken != null ? "present" : "missing"}',
      );
      print('[ForegroundService] Current semester ID: $currentSemesterId');
      print('[ForegroundService] Semesters string: $semestersStr');

      if (accessToken == null ||
          semestersStr == null ||
          currentSemesterId == null) {
        print('[ForegroundService] Missing required data');
        return;
      }

      final semesters = semestersStr.split(',').map((s) {
        final parts = s.split('|');
        return {'id': int.parse(parts[0]), 'name': parts[1]};
      }).toList();

      print(
        '[ForegroundService] Initializing NetworkClient and DataSources...',
      );

      // Initialize NetworkClient manually (since we are in isolate)
      final networkClient = NetworkClient(
        baseUrl: 'https://sinhvien1.tlu.edu.vn/education',
      );
      final jsonParser = DartJsonParser();

      final scheduleDataSource = ScheduleRemoteDataSourceImpl(
        client: networkClient,
        jsonParser: jsonParser,
      );

      final examDataSource = ExamRemoteDataSourceImpl(
        client: networkClient,
        jsonParser: jsonParser,
      );

      final dbHelper = DatabaseHelper.instance;

      await prefs.setInt('download_total_semesters', semesters.length);
      await prefs.setInt('download_completed_semesters', 0);

      // Phase 1: Download courses for all semesters
      print('[ForegroundService] Phase 1: Downloading courses...');
      int completed = 0;

      for (var semester in semesters) {
        final semesterId = semester['id'] as int;
        final semesterName = semester['name'] as String;

        // Skip current semester (already downloaded)
        if (semesterId == currentSemesterId) {
          completed++;
          await prefs.setInt('download_completed_semesters', completed);
          continue;
        }

        try {
          await prefs.setString(
            'download_current_semester_name',
            'Lịch học: $semesterName',
          );

          // Check cache
          final cached = await dbHelper.getStudentCourses(semesterId);
          if (cached.isNotEmpty) {
            print('[ForegroundService] Skipping $semesterName - cached');
            completed++;
            await prefs.setInt('download_completed_semesters', completed);
            continue;
          }

          // Download courses
          final coursesEntity = await scheduleDataSource.getCourses(
            semesterId,
            accessToken,
          );

          // Map Entity to Legacy Model
          final courses = coursesEntity
              .map(
                (c) => StudentCourseSubject(
                  id: c.id,
                  courseCode: c.courseCode,
                  courseName: c.courseName,
                  classCode: c.classCode ?? '',
                  className: c.className ?? '',
                  lecturer: (c.lecturerName != null || c.lecturerEmail != null)
                      ? LecturerInfo(
                          id: 0,
                          name: c.lecturerName ?? '',
                          email: c.lecturerEmail ?? '',
                        )
                      : null,
                  dayOfWeek: c.dayOfWeek,
                  startCourseHour: c.startCourseHour,
                  endCourseHour: c.endCourseHour,
                  room: c.room,
                  building: c.building ?? '',
                  campus: c.campus ?? '',
                  credits: c.credits,
                  startDate: c.startDate,
                  endDate: c.endDate,
                  fromWeek: c.fromWeek,
                  toWeek: c.toWeek,
                  status: c.status,
                  grade: c.grade,
                ),
              )
              .toList();

          await dbHelper.saveStudentCourses(semesterId, courses);

          print(
            '[ForegroundService] Downloaded ${courses.length} courses for $semesterName',
          );
          completed++;
          await prefs.setInt('download_completed_semesters', completed);
        } catch (e) {
          print(
            '[ForegroundService] Error downloading courses for $semesterName: $e',
          );
        }
      }

      // Phase 2: Download exam data for all semesters
      print('[ForegroundService] Phase 2: Downloading exams...');
      completed = 0;
      await prefs.setInt('download_total_semesters', semesters.length);
      await prefs.setInt('download_completed_semesters', 0);

      for (var semester in semesters) {
        final semesterId = semester['id'] as int;
        final semesterName = semester['name'] as String;

        try {
          await prefs.setString(
            'download_current_semester_name',
            'Lịch thi: $semesterName',
          );

          // Check cache
          final hasCache = await dbHelper.hasRegisterPeriodsCache(semesterId);
          if (hasCache) {
            final periods = await dbHelper.getRegisterPeriods(semesterId);
            if (periods.isNotEmpty) {
              print(
                '[ForegroundService] Skipping exam for $semesterName - cached',
              );
              completed++;
              await prefs.setInt('download_completed_semesters', completed);
              continue;
            }
          }

          // Download register periods
          final schedules = await examDataSource.getExamSchedules(
            semesterId,
            accessToken,
          );

          // Map to Legacy RegisterPeriod
          // Need dummy Semester object for RegisterPeriod
          final dummySemester = Semester(
            id: semesterId,
            semesterCode: '',
            semesterName: semesterName,
            startDate: 0,
            endDate: 0,
            isCurrent: false,
            ordinalNumbers: 0,
            semesterRegisterPeriods: [],
          );

          final periods = schedules
              .map(
                (s) => RegisterPeriod(
                  id: s.id,
                  name: s.name,
                  displayOrder: s.displayOrder,
                  voided: s.voided,
                  semester: dummySemester,
                  examPeriods: [],
                ),
              )
              .toList();

          await dbHelper.saveRegisterPeriods(semesterId, periods);

          // Download exam rooms for all 5 rounds
          for (var period in periods) {
            for (int round = 1; round <= 5; round++) {
              try {
                final roomsEntity = await examDataSource.getExamRooms(
                  semesterId: semesterId,
                  scheduleId: period.id,
                  round: round,
                  accessToken: accessToken,
                );

                // Map to Legacy StudentExamRoom
                final examRooms = roomsEntity
                    .map(
                      (r) => StudentExamRoom(
                        id: r.id,
                        status: 0,
                        examCode: '',
                        examCodeNumber: 0,
                        markingCode: '',
                        examPeriodCode: r.examPeriodCode,
                        subjectName: r.subjectName,
                        studentCode: r.studentCode,
                        examRound: round,
                        examRoom: ExamRoomDetail(
                          id: 0,
                          roomCode: r.roomName ?? '',
                          duration: 0,
                          examDate: r.examDate?.millisecondsSinceEpoch,
                          examDateString: r.examDate?.toIso8601String(),
                          numberExpectedStudent: 0,
                          semesterName: '',
                          courseYearName: '',
                          registerPeriodName: '',
                          examHour: ExamHour(
                            id: 0,
                            startString: r.examTime ?? '',
                            endString: '',
                            name: '',
                            code: '',
                          ),
                          room: Room(id: 0, name: r.roomName ?? '', code: ''),
                        ),
                      ),
                    )
                    .toList();

                await dbHelper.saveExamRooms(
                  semesterId,
                  period.id,
                  round,
                  examRooms,
                );

                if (examRooms.isNotEmpty) {
                  print(
                    '[ForegroundService] Downloaded ${examRooms.length} exam rooms for $semesterName Round $round',
                  );
                }
              } catch (e) {
                print('[ForegroundService] Error downloading round $round: $e');
              }
            }
          }

          completed++;
          await prefs.setInt('download_completed_semesters', completed);
        } catch (e) {
          print(
            '[ForegroundService] Error downloading exams for $semesterName: $e',
          );
        }
      }

      // Mark complete
      print('[ForegroundService] ✅ Download complete!');
      await prefs.setBool('download_complete', true);
      await prefs.setBool('download_in_progress', false);
      await prefs.setInt(
        'download_completed_semesters',
        _totalSemesters,
      ); // Ensure 100%
      await prefs.setString(
        'download_current_semester_name',
        '',
      ); // Clear current

      // Update notification immediately
      await FlutterForegroundTask.updateService(
        notificationTitle: '✅ Tải dữ liệu hoàn tất',
        notificationText: 'Đã tải xong tất cả dữ liệu offline',
      );

      // Keep service alive for 5 seconds to show completion
      await Future.delayed(const Duration(seconds: 5));

      print('[ForegroundService] Stopping service...');
      await FlutterForegroundTask.stopService();

      // Clear sensitive data
      await prefs.remove('download_access_token');
    } catch (e) {
      print('[ForegroundService] Download error: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('download_in_progress', false);
    }
  }
}
