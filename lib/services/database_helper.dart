import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

// Clean Architecture Models & Entities
import '../features/auth/data/models/user_model.dart';
import '../features/schedule/data/models/course_model.dart';
import '../features/schedule/data/models/school_year_model.dart';
import '../features/schedule/data/models/semester_model.dart';
import '../features/schedule/domain/entities/course_hour.dart';

// Legacy compatibility for RegisterPeriod/Exam
// Use alias to avoid conflicts (e.g. ExamHour vs CourseHour check, or Room vs something else)
import '../features/exam/data/models/exam_dtos.dart' as Legacy;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB('tlu_calendar.db');
    return _database!;
  }

  Future<void> ensureInitialized() async {
    if (_database == null || !_database!.isOpen) {
      _database = null;
      await database;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS users');
    await db.execute('DROP TABLE IF EXISTS course_hours');
    await db.execute('DROP TABLE IF EXISTS semesters');
    await db.execute('DROP TABLE IF EXISTS student_courses');
    await db.execute('DROP TABLE IF EXISTS school_years');
    await db.execute('DROP TABLE IF EXISTS register_periods');
    await db.execute('DROP TABLE IF EXISTS exam_rooms');
    await db.execute('DROP TABLE IF EXISTS cache_progress');
    await db.execute('DROP TABLE IF EXISTS exam_round_cache_metadata');

    await _createDB(db, newVersion);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE register_periods (
        id INTEGER PRIMARY KEY,
        semesterId INTEGER NOT NULL,
        name TEXT NOT NULL,
        displayOrder INTEGER NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    await db.execute('''
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

    await db.execute('''
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

    await db.insert('cache_progress', {
      'id': 1,
      'isComplete': 0,
      'totalSemesters': 0,
      'cachedSemesters': 0,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    });

    await db.execute('''
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
    await db.insert('users', {
      'id': 1,
      'username': user.studentId,
      'displayName': user.fullName,
      'email': user.email,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserModel?> getUser() async {
    final db = await database;
    final maps = await db.query('users', limit: 1);
    if (maps.isEmpty) return null;
    final map = maps.first;
    return UserModel(
      studentId: map['username'] as String,
      fullName: map['displayName'] as String,
      email: map['email'] as String,
      profileImageUrl: null,
    );
  }

  // --- COURSE HOURS ---
  Future<void> saveCourseHours(Map<int, CourseHour> courseHours) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var hour in courseHours.values) {
      batch.insert('course_hours', {
        'id': hour.id,
        'name': hour.name,
        'startString': hour.startString,
        'endString': hour.endString,
        'indexNumber': hour.indexNumber,
        'type': 0,
        'lastUpdated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<int, CourseHour>> getCourseHours() async {
    final db = await database;
    final maps = await db.query('course_hours');
    final courseHours = <int, CourseHour>{};
    for (var map in maps) {
      final hour = CourseHour(
        id: map['id'] as int,
        name: map['name'] as String,
        startString: map['startString'] as String,
        endString: map['endString'] as String,
        indexNumber: map['indexNumber'] as int,
      );
      courseHours[hour.id] = hour;
    }
    return courseHours;
  }

  // --- SEMESTERS ---
  Future<void> saveSemesters(List<SemesterModel> semesters) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var semester in semesters) {
      batch.insert('semesters', {
        'id': semester.id,
        'semesterCode': semester.semesterCode,
        'semesterName': semester.semesterName,
        'startDate': semester.startDate,
        'endDate': semester.endDate,
        'isCurrent': semester.isCurrent ? 1 : 0,
        'lastUpdated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<SemesterModel>> getSemesters() async {
    final db = await database;
    final maps = await db.query('semesters', orderBy: 'startDate DESC');
    return maps
        .map(
          (map) => SemesterModel(
            id: map['id'] as int,
            semesterCode: map['semesterCode'] as String,
            semesterName: map['semesterName'] as String,
            startDate: map['startDate'] as int,
            endDate: map['endDate'] as int,
            isCurrent: (map['isCurrent'] as int) == 1,
          ),
        )
        .toList();
  }

  // --- COURSES ---
  Future<void> saveCourses(int semesterId, List<CourseModel> courses) async {
    final db = await database;
    await db.delete(
      'student_courses',
      where: 'semesterId = ?',
      whereArgs: [semesterId],
    );
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var course in courses) {
      batch.insert('student_courses', {
        'courseId': course.id,
        'semesterId': semesterId,
        'courseCode': course.courseCode,
        'courseName': course.courseName,
        'classCode': course.classCode,
        'className': course.className,
        'dayOfWeek': course.dayOfWeek,
        'startCourseHour': course.startCourseHour,
        'endCourseHour': course.endCourseHour,
        'room': course.room,
        'building': course.building,
        'campus': course.campus,
        'credits': course.credits,
        'startDate': course.startDate,
        'endDate': course.endDate,
        'fromWeek': course.fromWeek,
        'toWeek': course.toWeek,
        'status': course.status,
        'grade': course.grade,
        'lecturerName': course.lecturerName,
        'lecturerEmail': course.lecturerEmail,
        'lastUpdated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<CourseModel>> getCourses(int semesterId) async {
    final db = await database;
    final maps = await db.query(
      'student_courses',
      where: 'semesterId = ?',
      whereArgs: [semesterId],
      orderBy: 'dayOfWeek, startCourseHour',
    );
    return maps
        .map(
          (map) => CourseModel(
            id: map['courseId'] as int,
            courseCode: map['courseCode'] as String,
            courseName: map['courseName'] as String,
            classCode: map['classCode'] as String?,
            className: map['className'] as String?,
            dayOfWeek: map['dayOfWeek'] as int,
            startCourseHour: map['startCourseHour'] as int,
            endCourseHour: map['endCourseHour'] as int,
            room: map['room'] as String,
            building: map['building'] as String?,
            campus: map['campus'] as String?,
            credits: map['credits'] as int? ?? 0,
            startDate: map['startDate'] as int,
            endDate: map['endDate'] as int,
            fromWeek: map['fromWeek'] as int,
            toWeek: map['toWeek'] as int,
            status: map['status'] as String,
            grade: map['grade'] as double?,
            lecturerName: map['lecturerName'] as String?,
            lecturerEmail: map['lecturerEmail'] as String?,
          ),
        )
        .toList();
  }

  // --- SCHOOL YEARS ---
  Future<void> saveSchoolYears(List<SchoolYearModel> schoolYears) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var year in schoolYears) {
      batch.insert('school_years', {
        'id': year.id,
        'name': year.name,
        'code': year.code,
        'year': year.year,
        'current': year.current ? 1 : 0,
        'startDate': year.startDate,
        'endDate': year.endDate,
        'displayName': year.displayName,
        'lastUpdated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<SchoolYearModel>> getSchoolYears() async {
    final db = await database;
    final maps = await db.query('school_years', orderBy: 'year DESC');
    return maps
        .map(
          (map) => SchoolYearModel(
            id: map['id'] as int,
            name: map['name'] as String,
            code: map['code'] as String,
            year: map['year'] as int,
            current: (map['current'] as int) == 1,
            startDate: map['startDate'] as int,
            endDate: map['endDate'] as int,
            displayName: map['displayName'] as String,
            semesters:
                [], // Empty list as we don't store them nested in raw DB table
          ),
        )
        .toList();
  }

  // --- CLEAR DATA ---
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('student_courses');
    await db.delete('semesters');
    await db.delete('school_years');
    await db.delete('course_hours');
    await db.delete('register_periods');
    await db.delete('exam_rooms');
  }

  // Save register periods
  Future<void> saveRegisterPeriods(
    int semesterId,
    List<dynamic> periods,
  ) async {
    final db = await database;
    await db.delete(
      'register_periods',
      where: 'semesterId = ?',
      whereArgs: [semesterId],
    );
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var period in periods) {
      batch.insert('register_periods', {
        'id': (period as dynamic).id,
        'semesterId': semesterId,
        'name': period.name,
        'displayOrder': period.displayOrder,
        'lastUpdated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getRegisterPeriodsMaps(
    int semesterId,
  ) async {
    final db = await database;
    return await db.query(
      'register_periods',
      where: 'semesterId = ?',
      whereArgs: [semesterId],
      orderBy: 'displayOrder',
    );
  }

  // Save exam rooms
  Future<void> saveExamRooms(
    int semesterId,
    int registerPeriodId,
    int examRound,
    List<Legacy.StudentExamRoom> rooms,
  ) async {
    final db = await database;
    await db.delete(
      'exam_rooms',
      where: 'semesterId = ? AND registerPeriodId = ? AND examRound = ?',
      whereArgs: [semesterId, registerPeriodId, examRound],
    );

    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var room in rooms) {
      batch.insert('exam_rooms', {
        'semesterId': semesterId,
        'registerPeriodId': registerPeriodId,
        'examRound': examRound,
        'examRoomId': room.id,
        'status': room.status,
        'examCode': room.examCode,
        'examCodeNumber': room.examCodeNumber,
        'markingCode': room.markingCode,
        'examPeriodCode': room.examPeriodCode,
        'subjectName': room.subjectName,
        'studentCode': room.studentCode,
        'roomCode': room.examRoom?.roomCode ?? '',
        'duration': room.examRoom?.duration,
        'examDate': room.examRoom?.examDate,
        'examDateString': room.examRoom?.examDateString,
        'numberExpectedStudent': room.examRoom?.numberExpectedStudent,
        'semesterName': room.examRoom?.semesterName,
        'courseYearName': room.examRoom?.courseYearName,
        'registerPeriodName': room.examRoom?.registerPeriodName,
        // Serialize nested objects if needed, or simplistic approach
        // Only saving essential fields for now as per schema
        'examHourJson': room.examRoom?.examHour != null
            ? jsonEncode({
                'id': room.examRoom!.examHour!.id,
                'name': room.examRoom!.examHour!.name,
                'startString': room.examRoom!.examHour!.startString,
                'endString': room.examRoom!.examHour!.endString,
                'code': room.examRoom!.examHour!.code,
              })
            : null,
        'roomJson': room.examRoom?.room != null
            ? jsonEncode({
                'id': room.examRoom!.room!.id,
                'name': room.examRoom!.room!.name,
                'code': room.examRoom!.room!.code,
              })
            : null,
        'lastUpdated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    // Update cache metadata
    await db.insert('exam_round_cache_metadata', {
      'semesterId': semesterId,
      'registerPeriodId': registerPeriodId,
      'examRound': examRound,
      'roomCount': rooms.length,
      'lastCached': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get exam rooms
  Future<List<Legacy.StudentExamRoom>> getExamRooms(
    int semesterId,
    int registerPeriodId,
    int examRound,
  ) async {
    final db = await database;
    final maps = await db.query(
      'exam_rooms',
      where: 'semesterId = ? AND registerPeriodId = ? AND examRound = ?',
      whereArgs: [semesterId, registerPeriodId, examRound],
      orderBy: 'examDate, examDateString',
    );

    return maps.map((map) {
      Legacy.ExamHour? examHour;
      if (map['examHourJson'] != null) {
        final hourMap = jsonDecode(map['examHourJson'] as String);
        examHour = Legacy.ExamHour(
          id: hourMap['id'],
          startString: hourMap['startString'],
          endString: hourMap['endString'],
          name: hourMap['name'],
          code: hourMap['code'], // Now optional in definition, or we keep it.
          start: 0,
          end: 0,
          indexNumber: 0,
          type: 0,
        );
      }

      Legacy.Room? room;
      if (map['roomJson'] != null) {
        final roomMap = jsonDecode(map['roomJson'] as String);
        room = Legacy.Room(
          id: roomMap['id'],
          name: roomMap['name'],
          code: roomMap['code'],
        );
      }

      Legacy.ExamRoomDetail? examRoomDetail;
      if (map['roomCode'] != null && (map['roomCode'] as String).isNotEmpty) {
        examRoomDetail = Legacy.ExamRoomDetail(
          id: 0,
          roomCode: map['roomCode'] as String,
          duration: map['duration'] as int?,
          examDate: map['examDate'] as int?,
          examDateString: map['examDateString'] as String?,
          numberExpectedStudent: map['numberExpectedStudent'] as int?,
          semesterName: map['semesterName'] as String?,
          courseYearName: map['courseYearName'] as String?,
          registerPeriodName: map['registerPeriodName'] as String?,
          examHour: examHour,
          room: room,
          examCode: map['examCode'] as String?,
          studentCode: map['studentCode'] as String?,
          markingCode: map['markingCode'] as String?,
          subjectName: map['subjectName'] as String?,
          status: map['status'] as int?,
        );
      }

      return Legacy.StudentExamRoom(
        id: map['examRoomId'] as int,
        status: map['status'] as int,
        examCode: map['examCode'] as String?,
        examCodeNumber: map['examCodeNumber'] as int?,
        markingCode: map['markingCode'] as String?,
        examPeriodCode: map['examPeriodCode'] as String,
        subjectName: map['subjectName'] as String,
        studentCode: map['studentCode'] as String?,
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
    final result = await db.query(
      'exam_round_cache_metadata',
      where: 'semesterId = ? AND registerPeriodId = ? AND examRound = ?',
      whereArgs: [semesterId, registerPeriodId, examRound],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Check if cached register periods exist
  Future<bool> hasRegisterPeriodsCache(int semesterId) async {
    final db = await database;
    final result = await db.query(
      'register_periods',
      where: 'semesterId = ?',
      whereArgs: [semesterId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>> getCacheProgress() async {
    final db = await database;
    final result = await db.query('cache_progress', where: 'id = 1');
    if (result.isEmpty) {
      await db.insert('cache_progress', {
        'id': 1,
        'isComplete': 0,
        'totalSemesters': 0,
        'cachedSemesters': 0,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      return {'isComplete': false, 'totalSemesters': 0, 'cachedSemesters': 0};
    }
    return result.first;
  }

  Future<void> updateCacheProgress(
    int totalSemesters,
    int cachedSemesters, {
    bool? isComplete,
    int? currentSemesterId,
    String? currentSemesterName,
  }) async {
    final db = await database;
    final Map<String, dynamic> data = {
      'totalSemesters': totalSemesters,
      'cachedSemesters': cachedSemesters,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
    if (isComplete != null) data['isComplete'] = isComplete ? 1 : 0;
    if (currentSemesterId != null)
      data['currentSemesterId'] = currentSemesterId;
    if (currentSemesterName != null)
      data['currentSemesterName'] = currentSemesterName;

    await db.update('cache_progress', data, where: 'id = 1');
  }
}
