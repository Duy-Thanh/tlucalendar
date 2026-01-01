import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

// Clean Architecture Models & Entities
import '../features/auth/data/models/user_model.dart';
import '../features/schedule/data/models/course_model.dart';
import '../features/schedule/data/models/school_year_model.dart';
import '../features/schedule/data/models/semester_model.dart';
import '../features/schedule/domain/entities/course_hour.dart';

// Legacy compatibility for RegisterPeriod/Exam
import '../features/exam/data/models/exam_dtos.dart' as Legacy;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tlu_calendar.db');
    return _database!;
  }

  Future<void> ensureInitialized() async {
    if (_database == null) {
      await database;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, filePath);

    // Ensure directory exists
    try {
      await Directory(dirname(dbPath)).create(recursive: true);
    } catch (_) {}

    final db = sqlite3.open(dbPath);
    return _configureDB(db);
  }

  Future<Database> _configureDB(Database db) async {
    // Busy timeout for concurrency
    db.execute('PRAGMA busy_timeout = 3000;');

    // Enable WAL mode for better concurrency
    db.execute('PRAGMA journal_mode = WAL;');

    final currentVersionRow = db.select('PRAGMA user_version;');
    final currentVersion = currentVersionRow.first['user_version'] as int;
    const targetVersion = 5;

    if (currentVersion == 0) {
      _createDB(db, targetVersion);
    } else if (currentVersion < targetVersion) {
      _onUpgrade(db, currentVersion, targetVersion);
    }

    if (currentVersion != targetVersion) {
      db.execute('PRAGMA user_version = $targetVersion;');
    }

    return db;
  }

  // Exposed for Backup/Restore
  Future<String> get databasePath async {
    final docsDir = await getApplicationDocumentsDirectory();
    return join(docsDir.path, 'tlu_calendar.db');
  }

  Future<void> close() async {
    if (_database != null) {
      _database!.dispose();
      _database = null;
    }
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) {
    // Ideally we would do incremental upgrades, but for this migration/demo
    // we'll stick to the "nuclear option" if schema changed cleanly,
    // or just drop tables as in the previous helper.
    db.execute('DROP TABLE IF EXISTS users');
    db.execute('DROP TABLE IF EXISTS course_hours');
    db.execute('DROP TABLE IF EXISTS semesters');
    db.execute('DROP TABLE IF EXISTS student_courses');
    db.execute('DROP TABLE IF EXISTS school_years');
    db.execute('DROP TABLE IF EXISTS register_periods');
    db.execute('DROP TABLE IF EXISTS exam_rooms');
    db.execute('DROP TABLE IF EXISTS cache_progress');
    db.execute('DROP TABLE IF EXISTS exam_round_cache_metadata');

    _createDB(db, newVersion);
  }

  void _createDB(Database db, int version) {
    db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL,
        displayName TEXT NOT NULL,
        email TEXT NOT NULL,
        courseYear TEXT, 
        className TEXT,
        major TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE course_hours (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        startString TEXT NOT NULL,
        endString TEXT NOT NULL,
        indexNumber INTEGER NOT NULL,
        type INTEGER,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE semesters (
        id INTEGER PRIMARY KEY,
        semesterCode TEXT NOT NULL,
        semesterName TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER NOT NULL,
        isCurrent INTEGER NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE student_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,
        semesterId INTEGER NOT NULL,
        courseCode TEXT NOT NULL,
        courseName TEXT NOT NULL,
        classCode TEXT,
        className TEXT,
        dayOfWeek INTEGER NOT NULL,
        startCourseHour INTEGER NOT NULL,
        endCourseHour INTEGER NOT NULL,
        room TEXT NOT NULL,
        building TEXT,
        campus TEXT,
        credits INTEGER NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER NOT NULL,
        fromWeek INTEGER NOT NULL,
        toWeek INTEGER NOT NULL,
        status TEXT NOT NULL,
        grade REAL,
        lecturerName TEXT,
        lecturerEmail TEXT,
        lastUpdated INTEGER NOT NULL,
        UNIQUE(courseId, semesterId, dayOfWeek, fromWeek, toWeek)
      )
    ''');

    db.execute('''
      CREATE TABLE school_years (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        year INTEGER NOT NULL,
        current INTEGER NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER NOT NULL,
        displayName TEXT NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE register_periods (
        id INTEGER PRIMARY KEY,
        semesterId INTEGER NOT NULL,
        name TEXT NOT NULL,
        displayOrder INTEGER NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE exam_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        semesterId INTEGER NOT NULL,
        registerPeriodId INTEGER NOT NULL,
        examRound INTEGER NOT NULL,
        examRoomId INTEGER NOT NULL,
        status INTEGER NOT NULL,
        examCode TEXT,
        examCodeNumber INTEGER,
        markingCode TEXT,
        examPeriodCode TEXT NOT NULL,
        subjectName TEXT NOT NULL,
        studentCode TEXT,
        roomCode TEXT NOT NULL,
        duration INTEGER,
        examDate INTEGER,
        examDateString TEXT,
        numberExpectedStudent INTEGER,
        semesterName TEXT,
        courseYearName TEXT,
        registerPeriodName TEXT,
        examHourJson TEXT,
        roomJson TEXT,
        lastUpdated INTEGER NOT NULL,
        UNIQUE(examRoomId, semesterId, registerPeriodId, examRound)
      )
    ''');

    db.execute('''
      CREATE TABLE cache_progress (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        isComplete INTEGER NOT NULL DEFAULT 0,
        totalSemesters INTEGER NOT NULL DEFAULT 0,
        cachedSemesters INTEGER NOT NULL DEFAULT 0,
        currentSemesterId INTEGER,
        currentSemesterName TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    db.execute(
      'INSERT INTO cache_progress (id, isComplete, totalSemesters, cachedSemesters, lastUpdated) VALUES (1, 0, 0, 0, ?)',
      [DateTime.now().millisecondsSinceEpoch],
    );

    db.execute('''
      CREATE TABLE exam_round_cache_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        semesterId INTEGER NOT NULL,
        registerPeriodId INTEGER NOT NULL,
        examRound INTEGER NOT NULL,
        roomCount INTEGER NOT NULL DEFAULT 0,
        lastCached INTEGER NOT NULL,
        UNIQUE(semesterId, registerPeriodId, examRound)
      )
    ''');
  }

  // --- USER METHODS ---
  Future<void> saveUser(UserModel user) async {
    final db = await database;
    final stmt = db.prepare(
      'INSERT OR REPLACE INTO users (id, username, displayName, email, lastUpdated) VALUES (1, ?, ?, ?, ?)',
    );
    stmt.execute([
      user.studentId,
      user.fullName,
      user.email,
      DateTime.now().millisecondsSinceEpoch,
    ]);
    stmt.dispose();
  }

  Future<UserModel?> getUser() async {
    final db = await database;
    final results = db.select('SELECT * FROM users LIMIT 1');
    if (results.isEmpty) return null;
    final row = results.first;
    return UserModel(
      studentId: row['username'] as String,
      fullName: row['displayName'] as String,
      email: row['email'] as String,
      profileImageUrl: null,
    );
  }

  // --- COURSE HOURS ---
  Future<void> saveCourseHours(Map<int, CourseHour> courseHours) async {
    final db = await database;
    db.execute('BEGIN TRANSACTION');
    try {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO course_hours (id, name, startString, endString, indexNumber, type, lastUpdated) 
        VALUES (?, ?, ?, ?, ?, 0, ?)
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var hour in courseHours.values) {
        stmt.execute([
          hour.id,
          hour.name,
          hour.startString,
          hour.endString,
          hour.indexNumber,
          now,
        ]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Map<int, CourseHour>> getCourseHours() async {
    final db = await database;
    final results = db.select('SELECT * FROM course_hours');
    final courseHours = <int, CourseHour>{};
    for (var row in results) {
      final hour = CourseHour(
        id: row['id'] as int,
        name: row['name'] as String,
        startString: row['startString'] as String,
        endString: row['endString'] as String,
        indexNumber: row['indexNumber'] as int,
      );
      courseHours[hour.id] = hour;
    }
    return courseHours;
  }

  // --- SEMESTERS ---
  Future<void> saveSemesters(List<SemesterModel> semesters) async {
    final db = await database;
    db.execute('BEGIN TRANSACTION');
    try {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO semesters (id, semesterCode, semesterName, startDate, endDate, isCurrent, lastUpdated)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var semester in semesters) {
        stmt.execute([
          semester.id,
          semester.semesterCode,
          semester.semesterName,
          semester.startDate,
          semester.endDate,
          semester.isCurrent ? 1 : 0,
          now,
        ]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<SemesterModel>> getSemesters() async {
    final db = await database;
    final results = db.select(
      'SELECT * FROM semesters ORDER BY startDate DESC',
    );
    return results
        .map(
          (row) => SemesterModel(
            id: row['id'] as int,
            semesterCode: row['semesterCode'] as String,
            semesterName: row['semesterName'] as String,
            startDate: row['startDate'] as int,
            endDate: row['endDate'] as int,
            isCurrent: (row['isCurrent'] as int) == 1,
          ),
        )
        .toList();
  }

  // --- COURSES ---
  Future<void> saveCourses(int semesterId, List<CourseModel> courses) async {
    final db = await database;
    // Prepare statement for delete
    final delStmt = db.prepare(
      'DELETE FROM student_courses WHERE semesterId = ?',
    );
    delStmt.execute([semesterId]);
    delStmt.dispose();

    db.execute('BEGIN TRANSACTION');
    try {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO student_courses 
        (courseId, semesterId, courseCode, courseName, classCode, className, dayOfWeek, startCourseHour, endCourseHour, room, building, campus, credits, startDate, endDate, fromWeek, toWeek, status, grade, lecturerName, lecturerEmail, lastUpdated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var course in courses) {
        stmt.execute([
          course.id,
          semesterId,
          course.courseCode,
          course.courseName,
          course.classCode,
          course.className,
          course.dayOfWeek,
          course.startCourseHour,
          course.endCourseHour,
          course.room,
          course.building,
          course.campus,
          course.credits,
          course.startDate,
          course.endDate,
          course.fromWeek,
          course.toWeek,
          course.status,
          course.grade,
          course.lecturerName,
          course.lecturerEmail,
          now,
        ]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<CourseModel>> getCourses(int semesterId) async {
    final db = await database;
    final results = db.select(
      'SELECT * FROM student_courses WHERE semesterId = ? ORDER BY dayOfWeek, startCourseHour',
      [semesterId],
    );
    return results
        .map(
          (row) => CourseModel(
            id: row['courseId'] as int,
            courseCode: row['courseCode'] as String,
            courseName: row['courseName'] as String,
            classCode: row['classCode'] as String?,
            className: row['className'] as String?,
            dayOfWeek: row['dayOfWeek'] as int,
            startCourseHour: row['startCourseHour'] as int,
            endCourseHour: row['endCourseHour'] as int,
            room: row['room'] as String,
            building: row['building'] as String?,
            campus: row['campus'] as String?,
            credits: row['credits'] as int? ?? 0,
            startDate: row['startDate'] as int,
            endDate: row['endDate'] as int,
            fromWeek: row['fromWeek'] as int,
            toWeek: row['toWeek'] as int,
            status: row['status'] as String,
            grade: row['grade'] as double?,
            lecturerName: row['lecturerName'] as String?,
            lecturerEmail: row['lecturerEmail'] as String?,
          ),
        )
        .toList();
  }

  // --- SCHOOL YEARS ---
  Future<void> saveSchoolYears(List<SchoolYearModel> schoolYears) async {
    final db = await database;
    db.execute('BEGIN TRANSACTION');
    try {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO school_years (id, name, code, year, current, startDate, endDate, displayName, lastUpdated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var year in schoolYears) {
        stmt.execute([
          year.id,
          year.name,
          year.code,
          year.year,
          year.current ? 1 : 0,
          year.startDate,
          year.endDate,
          year.displayName,
          now,
        ]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<SchoolYearModel>> getSchoolYears() async {
    final db = await database;
    final results = db.select('SELECT * FROM school_years ORDER BY year DESC');
    return results
        .map(
          (row) => SchoolYearModel(
            id: row['id'] as int,
            name: row['name'] as String,
            code: row['code'] as String,
            year: row['year'] as int,
            current: (row['current'] as int) == 1,
            startDate: row['startDate'] as int,
            endDate: row['endDate'] as int,
            displayName: row['displayName'] as String,
            semesters: [],
          ),
        )
        .toList();
  }

  // --- CLEAR DATA ---
  Future<void> clearAllData() async {
    final db = await database;
    db.execute('DELETE FROM users');
    db.execute('DELETE FROM student_courses');
    db.execute('DELETE FROM semesters');
    db.execute('DELETE FROM school_years');
    db.execute('DELETE FROM course_hours');
    db.execute('DELETE FROM register_periods');
    db.execute('DELETE FROM exam_rooms');
  }

  // Save register periods
  Future<void> saveRegisterPeriods(
    int semesterId,
    List<dynamic> periods,
  ) async {
    final db = await database;

    final delStmt = db.prepare(
      'DELETE FROM register_periods WHERE semesterId = ?',
    );
    delStmt.execute([semesterId]);
    delStmt.dispose();

    db.execute('BEGIN TRANSACTION');
    try {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO register_periods (id, semesterId, name, displayOrder, lastUpdated)
        VALUES (?, ?, ?, ?, ?)
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var period in periods) {
        stmt.execute([
          (period as dynamic).id,
          semesterId,
          period.name,
          period.displayOrder,
          now,
        ]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRegisterPeriodsMaps(
    int semesterId,
  ) async {
    final db = await database;
    final results = db.select(
      'SELECT * FROM register_periods WHERE semesterId = ? ORDER BY displayOrder',
      [semesterId],
    );
    // Convert ResultSet to List<Map>
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // Save exam rooms
  Future<void> saveExamRooms(
    int semesterId,
    int registerPeriodId,
    int examRound,
    List<Legacy.StudentExamRoom> rooms,
  ) async {
    final db = await database;

    final delStmt = db.prepare(
      'DELETE FROM exam_rooms WHERE semesterId = ? AND registerPeriodId = ? AND examRound = ?',
    );
    delStmt.execute([semesterId, registerPeriodId, examRound]);
    delStmt.dispose();

    db.execute('BEGIN TRANSACTION');
    try {
      final stmt = db.prepare('''
        INSERT OR REPLACE INTO exam_rooms 
        (semesterId, registerPeriodId, examRound, examRoomId, status, examCode, examCodeNumber, markingCode, examPeriodCode, subjectName, studentCode, roomCode, duration, examDate, examDateString, numberExpectedStudent, semesterName, courseYearName, registerPeriodName, examHourJson, roomJson, lastUpdated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var room in rooms) {
        stmt.execute([
          semesterId,
          registerPeriodId,
          examRound,
          room.id,
          room.status,
          room.examCode,
          room.examCodeNumber,
          room.markingCode,
          room.examPeriodCode,
          room.subjectName,
          room.studentCode,
          room.examRoom?.roomCode ?? '',
          room.examRoom?.duration,
          room.examRoom?.examDate,
          room.examRoom?.examDateString,
          room.examRoom?.numberExpectedStudent,
          room.examRoom?.semesterName,
          room.examRoom?.courseYearName,
          room.examRoom?.registerPeriodName,
          room.examRoom?.examHour != null
              ? jsonEncode({
                  'id': room.examRoom!.examHour!.id,
                  'name': room.examRoom!.examHour!.name,
                  'startString': room.examRoom!.examHour!.startString,
                  'endString': room.examRoom!.examHour!.endString,
                  'code': room.examRoom!.examHour!.code,
                })
              : null,
          room.examRoom?.room != null
              ? jsonEncode({
                  'id': room.examRoom!.room!.id,
                  'name': room.examRoom!.room!.name,
                  'code': room.examRoom!.room!.code,
                })
              : null,
          now,
        ]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    // Update cache metadata
    final cacheStmt = db.prepare('''
      INSERT OR REPLACE INTO exam_round_cache_metadata 
      (semesterId, registerPeriodId, examRound, roomCount, lastCached)
      VALUES (?, ?, ?, ?, ?)
    ''');
    cacheStmt.execute([
      semesterId,
      registerPeriodId,
      examRound,
      rooms.length,
      DateTime.now().millisecondsSinceEpoch,
    ]);
    cacheStmt.dispose();
  }

  // Get exam rooms
  Future<List<Legacy.StudentExamRoom>> getExamRooms(
    int semesterId,
    int registerPeriodId,
    int examRound,
  ) async {
    final db = await database;
    final results = db.select(
      'SELECT * FROM exam_rooms WHERE semesterId = ? AND registerPeriodId = ? AND examRound = ? ORDER BY examDate, examDateString',
      [semesterId, registerPeriodId, examRound],
    );

    return results.map((row) {
      Legacy.ExamHour? examHour;
      if (row['examHourJson'] != null) {
        final hourMap = jsonDecode(row['examHourJson'] as String);
        examHour = Legacy.ExamHour(
          id: hourMap['id'],
          startString: hourMap['startString'],
          endString: hourMap['endString'],
          name: hourMap['name'],
          code: hourMap['code'],
          start: 0,
          end: 0,
          indexNumber: 0,
          type: 0,
        );
      }

      Legacy.Room? room;
      if (row['roomJson'] != null) {
        final roomMap = jsonDecode(row['roomJson'] as String);
        room = Legacy.Room(
          id: roomMap['id'],
          name: roomMap['name'],
          code: roomMap['code'],
        );
      }

      Legacy.ExamRoomDetail? examRoomDetail;
      if (row['roomCode'] != null && (row['roomCode'] as String).isNotEmpty) {
        examRoomDetail = Legacy.ExamRoomDetail(
          id: 0,
          roomCode: row['roomCode'] as String,
          duration: row['duration'] as int?,
          examDate: row['examDate'] as int?,
          examDateString: row['examDateString'] as String?,
          numberExpectedStudent: row['numberExpectedStudent'] as int?,
          semesterName: row['semesterName'] as String?,
          courseYearName: row['courseYearName'] as String?,
          registerPeriodName: row['registerPeriodName'] as String?,
          examHour: examHour,
          room: room,
          examCode: row['examCode'] as String?,
          studentCode: row['studentCode'] as String?,
          markingCode: row['markingCode'] as String?,
          subjectName: row['subjectName'] as String?,
          status: row['status'] as int?,
        );
      }

      return Legacy.StudentExamRoom(
        id: row['examRoomId'] as int,
        status: row['status'] as int,
        examCode: row['examCode'] as String?,
        examCodeNumber: row['examCodeNumber'] as int?,
        markingCode: row['markingCode'] as String?,
        examPeriodCode: row['examPeriodCode'] as String,
        subjectName: row['subjectName'] as String,
        studentCode: row['studentCode'] as String?,
        examRound: examRound,
        examRoom: examRoomDetail,
      );
    }).toList();
  }

  // Check if cached exam data exists
  Future<bool> hasExamRoomCache(
    int semesterId,
    int registerPeriodId,
    int examRound,
  ) async {
    final db = await database;
    final results = db.select(
      'SELECT 1 FROM exam_round_cache_metadata WHERE semesterId = ? AND registerPeriodId = ? AND examRound = ? LIMIT 1',
      [semesterId, registerPeriodId, examRound],
    );
    return results.isNotEmpty;
  }

  // Check if cached register periods exist
  Future<bool> hasRegisterPeriodsCache(int semesterId) async {
    final db = await database;
    final results = db.select(
      'SELECT 1 FROM register_periods WHERE semesterId = ? LIMIT 1',
      [semesterId],
    );
    return results.isNotEmpty;
  }

  Future<Map<String, dynamic>> getCacheProgress() async {
    final db = await database;
    final results = db.select('SELECT * FROM cache_progress WHERE id = 1');
    if (results.isEmpty) {
      db.execute(
        'INSERT INTO cache_progress (id, isComplete, totalSemesters, cachedSemesters, lastUpdated) VALUES (1, 0, 0, 0, ?)',
        [DateTime.now().millisecondsSinceEpoch],
      );
      return {'isComplete': false, 'totalSemesters': 0, 'cachedSemesters': 0};
    }
    // Convert ResultSet Row to Map
    final row = results.first;
    return {
      'isComplete': row['isComplete'] == 1,
      'totalSemesters': row['totalSemesters'],
      'cachedSemesters': row['cachedSemesters'],
      'currentSemesterId': row['currentSemesterId'],
      'currentSemesterName': row['currentSemesterName'],
      'lastUpdated': row['lastUpdated'],
    };
  }

  Future<void> updateCacheProgress(
    int totalSemesters,
    int cachedSemesters, {
    bool? isComplete,
    int? currentSemesterId,
    String? currentSemesterName,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Build update query dynamically
    final updates = <String>[];
    final args = <Object?>[];

    updates.add('totalSemesters = ?');
    args.add(totalSemesters);

    updates.add('cachedSemesters = ?');
    args.add(cachedSemesters);

    updates.add('lastUpdated = ?');
    args.add(now);

    if (isComplete != null) {
      updates.add('isComplete = ?');
      args.add(isComplete ? 1 : 0);
    }
    if (currentSemesterId != null) {
      updates.add('currentSemesterId = ?');
      args.add(currentSemesterId);
    }
    if (currentSemesterName != null) {
      updates.add('currentSemesterName = ?');
      args.add(currentSemesterName);
    }

    final query =
        'UPDATE cache_progress SET ${updates.join(", ")} WHERE id = 1';
    db.execute(query, args);
  }
}
