import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/api_response.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tlu_calendar.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // User table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL,
        displayName TEXT NOT NULL,
        email TEXT NOT NULL,
        personJson TEXT,
        rolesJson TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Course hours table (Tiết 1-15)
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

    // Semesters table
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

    // Student courses table
    await db.execute('''
      CREATE TABLE student_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,
        semesterId INTEGER NOT NULL,
        courseCode TEXT NOT NULL,
        courseName TEXT NOT NULL,
        classCode TEXT,
        className TEXT,
        lecturerJson TEXT,
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
        lastUpdated INTEGER NOT NULL,
        UNIQUE(courseId, semesterId, dayOfWeek, fromWeek, toWeek)
      )
    ''');

    // School years table
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
  }

  // Save TLU user
  Future<void> saveTluUser(TluUser user) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'email': user.email,
        'personJson': user.person != null ? jsonEncode(_personToMap(user.person!)) : null,
        'rolesJson': jsonEncode(user.roles.map((r) => {'id': r.id, 'name': r.name, 'authority': r.authority}).toList()),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _personToMap(Person person) {
    return {
      'id': person.id,
      'firstName': person.firstName,
      'lastName': person.lastName,
      'displayName': person.displayName,
      'birthDateString': person.birthDateString,
      'birthPlace': person.birthPlace,
      'gender': person.gender,
      'phoneNumber': person.phoneNumber,
      'idNumber': person.idNumber,
      'email': person.email,
    };
  }

  // Get TLU user
  Future<TluUser?> getTluUser() async {
    final db = await database;
    final maps = await db.query('users', limit: 1);
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return TluUser(
      id: map['id'] as int,
      username: map['username'] as String,
      displayName: map['displayName'] as String,
      email: map['email'] as String,
      active: true,
      person: map['personJson'] != null ? _mapToPerson(jsonDecode(map['personJson'] as String)) : null,
      roles: (jsonDecode(map['rolesJson'] as String) as List)
          .map((r) => UserRole(id: r['id'], name: r['name'], authority: r['authority']))
          .toList(),
    );
  }

  Person _mapToPerson(Map<String, dynamic> map) {
    return Person(
      id: map['id'],
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      displayName: map['displayName'] ?? '',
      birthDateString: map['birthDateString'],
      birthPlace: map['birthPlace'] ?? '',
      gender: map['gender'] ?? 'M',
      phoneNumber: map['phoneNumber'] ?? '',
      idNumber: map['idNumber'] ?? '',
      email: map['email'] ?? '',
      address: [],
    );
  }

  // Save course hours
  Future<void> saveCourseHours(Map<int, CourseHour> courseHours) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var hour in courseHours.values) {
      batch.insert(
        'course_hours',
        {
          'id': hour.id,
          'name': hour.name,
          'startString': hour.startString,
          'endString': hour.endString,
          'indexNumber': hour.indexNumber,
          'type': hour.type,
          'lastUpdated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get course hours
  Future<Map<int, CourseHour>> getCourseHours() async {
    final db = await database;
    final maps = await db.query('course_hours');
    
    final courseHours = <int, CourseHour>{};
    for (var map in maps) {
      final hour = CourseHour(
        id: map['id'] as int,
        name: map['name'] as String,
        start: 0,
        startString: map['startString'] as String,
        end: 0,
        endString: map['endString'] as String,
        indexNumber: map['indexNumber'] as int,
        type: (map['type'] as int?) ?? 0,
      );
      courseHours[hour.id] = hour;
    }
    
    return courseHours;
  }

  // Save semesters
  Future<void> saveSemesters(List<Semester> semesters) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var semester in semesters) {
      batch.insert(
        'semesters',
        {
          'id': semester.id,
          'semesterCode': semester.semesterCode,
          'semesterName': semester.semesterName,
          'startDate': semester.startDate,
          'endDate': semester.endDate,
          'isCurrent': semester.isCurrent ? 1 : 0,
          'lastUpdated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get semesters
  Future<List<Semester>> getSemesters() async {
    final db = await database;
    final maps = await db.query('semesters', orderBy: 'startDate DESC');
    
    return maps.map((map) => Semester(
      id: map['id'] as int,
      semesterCode: map['semesterCode'] as String,
      semesterName: map['semesterName'] as String,
      startDate: map['startDate'] as int,
      endDate: map['endDate'] as int,
      isCurrent: (map['isCurrent'] as int) == 1,
      semesterRegisterPeriods: [],
    )).toList();
  }

  // Save student courses
  Future<void> saveStudentCourses(int semesterId, List<StudentCourseSubject> courses) async {
    final db = await database;
    
    // Delete old courses for this semester
    await db.delete('student_courses', where: 'semesterId = ?', whereArgs: [semesterId]);
    
    // Insert new courses
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var course in courses) {
      batch.insert(
        'student_courses',
        {
          'courseId': course.id,
          'semesterId': semesterId,
          'courseCode': course.courseCode,
          'courseName': course.courseName,
          'classCode': course.classCode,
          'className': course.className,
          'lecturerJson': course.lecturer != null 
              ? jsonEncode({
                  'id': course.lecturer!.id,
                  'name': course.lecturer!.name,
                  'email': course.lecturer!.email,
                })
              : null,
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
          'lastUpdated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get student courses for a semester
  Future<List<StudentCourseSubject>> getStudentCourses(int semesterId) async {
    final db = await database;
    final maps = await db.query(
      'student_courses',
      where: 'semesterId = ?',
      whereArgs: [semesterId],
      orderBy: 'dayOfWeek, startCourseHour',
    );
    
    return maps.map((map) {
      LecturerInfo? lecturer;
      if (map['lecturerJson'] != null) {
        final lecturerMap = jsonDecode(map['lecturerJson'] as String);
        lecturer = LecturerInfo(
          id: lecturerMap['id'],
          name: lecturerMap['name'],
          email: lecturerMap['email'],
        );
      }
      
      return StudentCourseSubject(
        id: map['courseId'] as int,
        courseCode: map['courseCode'] as String,
        courseName: map['courseName'] as String,
        classCode: map['classCode'] as String? ?? '',
        className: map['className'] as String? ?? '',
        lecturer: lecturer,
        dayOfWeek: map['dayOfWeek'] as int,
        startCourseHour: map['startCourseHour'] as int,
        endCourseHour: map['endCourseHour'] as int,
        room: map['room'] as String,
        building: map['building'] as String? ?? '',
        campus: map['campus'] as String? ?? '',
        credits: map['credits'] as int,
        startDate: map['startDate'] as int,
        endDate: map['endDate'] as int,
        fromWeek: map['fromWeek'] as int,
        toWeek: map['toWeek'] as int,
        status: map['status'] as String,
        grade: map['grade'] as double?,
      );
    }).toList();
  }

  // Save school years
  Future<void> saveSchoolYears(List<SchoolYear> schoolYears) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var year in schoolYears) {
      batch.insert(
        'school_years',
        {
          'id': year.id,
          'name': year.name,
          'code': year.code,
          'year': year.year,
          'current': year.current ? 1 : 0,
          'startDate': year.startDate,
          'endDate': year.endDate,
          'displayName': year.displayName,
          'lastUpdated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get school years
  Future<List<SchoolYear>> getSchoolYears() async {
    final db = await database;
    final maps = await db.query('school_years', orderBy: 'year DESC');
    
    return maps.map((map) => SchoolYear(
      id: map['id'] as int,
      name: map['name'] as String,
      code: map['code'] as String,
      year: map['year'] as int,
      current: (map['current'] as int) == 1,
      startDate: map['startDate'] as int,
      endDate: map['endDate'] as int,
      displayName: map['displayName'] as String,
      semesters: [],
    )).toList();
  }

  // Clear all data
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('course_hours');
    await db.delete('semesters');
    await db.delete('student_courses');
    await db.delete('school_years');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
