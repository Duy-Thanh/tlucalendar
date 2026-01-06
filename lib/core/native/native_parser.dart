import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:tlucalendar/features/exam/data/models/exam_schedule_model.dart';
import 'package:tlucalendar/features/exam/data/models/exam_room_model.dart';

import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/features/schedule/data/models/school_year_model.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_register_period_model.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/auth/data/models/user_model.dart';
import 'package:tlucalendar/features/registration/data/models/subject_registration_model.dart';

// --- FFI Structs matching C++ ---

final class BookingStatusNative extends Struct {
  @Int32()
  external int id;

  external Pointer<Utf8> name;
}

final class ExamPeriodNative extends Struct {
  @Int32()
  external int id;

  external Pointer<Utf8> examPeriodCode;
  external Pointer<Utf8> name;

  @Int64()
  external int startDate;

  @Int64()
  external int endDate;

  @Int32()
  external int numberOfExamDays;

  external BookingStatusNative bookingStatus;
}

final class ExamScheduleNative extends Struct {
  @Int32()
  external int id;

  external Pointer<Utf8> name;

  @Int32()
  external int displayOrder;

  @Bool()
  external bool voided;

  @Int32()
  external int examPeriodsCount;

  external Pointer<ExamPeriodNative> examPeriods; // Array ptr
}

final class ExamScheduleResult extends Struct {
  @Int32()
  external int count;

  external Pointer<ExamScheduleNative> schedules; // Array ptr

  external Pointer<Utf8> errorMessage;
}

final class ExamRoomNative extends Struct {
  @Int32()
  external int id;

  external Pointer<Utf8> subjectName;
  external Pointer<Utf8> examPeriodCode;
  external Pointer<Utf8> examCode;
  external Pointer<Utf8> studentCode;

  @Int64()
  external int examDate;

  external Pointer<Utf8> examTime;
  external Pointer<Utf8> roomName;
  external Pointer<Utf8> roomBuilding;
  external Pointer<Utf8> examMethod;
  external Pointer<Utf8> notes;

  @Int32()
  external int numberExpectedStudent;
}

final class ExamRoomResult extends Struct {
  @Int32()
  external int count;

  external Pointer<ExamRoomNative> rooms;

  external Pointer<Utf8> errorMessage;
}

final class CourseNative extends Struct {
  @Int32()
  external int id;

  external Pointer<Utf8> courseCode;
  external Pointer<Utf8> courseName;
  external Pointer<Utf8> classCode;
  external Pointer<Utf8> className;

  @Int32()
  external int dayOfWeek;
  @Int32()
  external int startCourseHour;
  @Int32()
  external int endCourseHour;

  external Pointer<Utf8> room;
  external Pointer<Utf8> building;
  external Pointer<Utf8> campus;

  @Int32()
  external int credits;

  @Int64()
  external int startDate;
  @Int64()
  external int endDate;

  @Int32()
  external int fromWeek;
  @Int32()
  external int toWeek;

  external Pointer<Utf8> lecturerName;
  external Pointer<Utf8> lecturerEmail;
  external Pointer<Utf8> status;

  @Double()
  external double grade;
  @Bool()
  external bool hasGrade;
}

final class CourseResult extends Struct {
  @Int32()
  external int count;

  external Pointer<CourseNative> courses;
  external Pointer<Utf8> errorMessage;
}

final class CourseHourNative extends Struct {
  @Int32()
  external int id;
  external Pointer<Utf8> name;
  external Pointer<Utf8> startString;
  external Pointer<Utf8> endString;
  @Int32()
  external int indexNumber;
}

final class CourseHourResult extends Struct {
  @Int32()
  external int count;
  external Pointer<CourseHourNative> hours;
  external Pointer<Utf8> errorMessage;
}

final class SemesterRegisterPeriodNative extends Struct {
  @Int32()
  external int id;
  external Pointer<Utf8> name;
  @Int64()
  external int startRegisterTime;
  @Int64()
  external int endRegisterTime;
  @Int64()
  external int endUnRegisterTime;
  external Pointer<Utf8> startRegisterTimeString;
  external Pointer<Utf8> endRegisterTimeString;
  external Pointer<Utf8> endUnRegisterTimeString;
}

final class SemesterNative extends Struct {
  @Int32()
  external int id;
  external Pointer<Utf8> semesterCode;
  external Pointer<Utf8> semesterName;
  @Int64()
  external int startDate;
  @Int64()
  external int endDate;
  @Bool()
  external bool isCurrent;
  @Int32()
  external int ordinalNumbers;

  @Int32()
  external int registerPeriodsCount;
  external Pointer<SemesterRegisterPeriodNative> registerPeriods;
}

final class SemesterResult extends Struct {
  external Pointer<SemesterNative> semester;
  external Pointer<Utf8> errorMessage;
}

final class SchoolYearNative extends Struct {
  @Int32()
  external int id;
  external Pointer<Utf8> name;
  external Pointer<Utf8> code;
  @Int32()
  external int year;
  @Bool()
  external bool current;
  @Int64()
  external int startDate;
  @Int64()
  external int endDate;
  external Pointer<Utf8> displayName;
  @Int32()
  external int semestersCount;
  external Pointer<SemesterNative> semesters;
}

final class SchoolYearResult extends Struct {
  @Int32()
  external int count;
  external Pointer<SchoolYearNative> years;
  external Pointer<Utf8> errorMessage;
}

final class UserNative extends Struct {
  external Pointer<Utf8> studentId;
  external Pointer<Utf8> fullName;
  external Pointer<Utf8> email;
  @Int32()
  external int id;
}

final class UserResult extends Struct {
  external Pointer<UserNative> user;
  external Pointer<Utf8> errorMessage;
}

final class TokenResponseNative extends Struct {
  external Pointer<Utf8> access_token;
  external Pointer<Utf8> token_type;
  external Pointer<Utf8> refresh_token;
  external Pointer<Utf8> scope;
  @Int32()
  external int expires_in;
}

final class TokenResponseResult extends Struct {
  external Pointer<TokenResponseNative> token;
  external Pointer<Utf8> errorMessage;
}

// --- Registration Structs ---
final class TimetableNative extends Struct {
  @Int32()
  external int id;
  @Int64()
  external int startDate;
  @Int64()
  external int endDate;
  @Int32()
  external int fromWeek;
  @Int32()
  external int toWeek;
  @Int32()
  external int dayOfWeek;
  @Int32()
  external int startHour;
  @Int32()
  external int endHour;
  external Pointer<Utf8> roomName;
  external Pointer<Utf8> teacherName;
}

final class CourseSubjectNative extends Struct {
  @Int32()
  external int id;
  external Pointer<Utf8> code;
  external Pointer<Utf8> name;
  external Pointer<Utf8> displayCode;
  @Int32()
  external int numberStudent;
  @Int32()
  external int maxStudent;
  @Int32()
  external int numberRegisted;
  @Bool()
  external bool isSelected;
  @Bool()
  external bool isFull;
  @Bool()
  external bool isOverlap;
  @Int32()
  external int timetablesCount;
  external Pointer<TimetableNative> timetables;
  @Int32()
  external int credits;
  external Pointer<Utf8> status;
}

final class SubjectRegistrationNative extends Struct {
  external Pointer<Utf8> subjectName;
  @Int32()
  external int numberOfCredit;
  @Int32()
  external int courseSubjectsCount;
  external Pointer<CourseSubjectNative> courseSubjects;
}

final class RegistrationPeriodNative extends Struct {
  @Int32()
  external int id;
  @Int32()
  external int subjectsCount;
  external Pointer<SubjectRegistrationNative> subjects;
}

final class RegistrationResult extends Struct {
  external Pointer<RegistrationPeriodNative> data;
  external Pointer<Utf8> errorMessage;
}

final class RegistrationActionNative extends Struct {
  @Int32()
  external int status;
  external Pointer<Utf8> message;
}

final class NotificationNative extends Struct {
  @Int64()
  external int triggerTime;
  external Pointer<Utf8> title;
  external Pointer<Utf8> body;
  @Int32()
  external int id; // Unique ID
}

final class NotificationResult extends Struct {
  @Int32()
  external int count;
  external Pointer<NotificationNative> notifications;
  external Pointer<Utf8> errorMessage;
}

class NotificationNativeModel {
  final int id;
  final int triggerTime;
  final String title;
  final String body;

  NotificationNativeModel({
    required this.id,
    required this.triggerTime,
    required this.title,
    required this.body,
  });
}

// --- Function Signatures ---

typedef ParseExamDetailsFunc =
    Pointer<ExamScheduleResult> Function(Pointer<Utf8>);
typedef ParseExamDetails = Pointer<ExamScheduleResult> Function(Pointer<Utf8>);

typedef ParseTokenFunc = Pointer<TokenResponseResult> Function(Pointer<Utf8>);
typedef ParseToken = Pointer<TokenResponseResult> Function(Pointer<Utf8>);
typedef FreeTokenResultFunc = Void Function(Pointer<TokenResponseResult>);
typedef FreeTokenResult = void Function(Pointer<TokenResponseResult>);

// ... other typedefs ...

typedef ParseExamRoomsFunc = Pointer<ExamRoomResult> Function(Pointer<Utf8>);
typedef ParseExamRooms = Pointer<ExamRoomResult> Function(Pointer<Utf8>);

typedef FreeExamRoomResultFunc = Void Function(Pointer<ExamRoomResult>);
typedef FreeExamRoomResult = void Function(Pointer<ExamRoomResult>);

typedef FreeResultFunc = Void Function(Pointer<ExamScheduleResult>);
typedef FreeResult = void Function(Pointer<ExamScheduleResult>);

typedef GetVersionFunc = Pointer<Utf8> Function();
typedef GetVersion = Pointer<Utf8> Function();

typedef ParseCountFunc = Int32 Function(Pointer<Utf8>);
typedef ParseCount = int Function(Pointer<Utf8>);

typedef ParseCoursesFunc = Pointer<CourseResult> Function(Pointer<Utf8>);
typedef ParseCourses = Pointer<CourseResult> Function(Pointer<Utf8>);

typedef FreeCourseResultFunc = Void Function(Pointer<CourseResult>);
typedef FreeCourseResult = void Function(Pointer<CourseResult>);

typedef ParseCourseHoursFunc =
    Pointer<CourseHourResult> Function(Pointer<Utf8>);
typedef ParseCourseHours = Pointer<CourseHourResult> Function(Pointer<Utf8>);

typedef ParseSchoolYearsFunc =
    Pointer<SchoolYearResult> Function(Pointer<Utf8>);
typedef ParseSchoolYears = Pointer<SchoolYearResult> Function(Pointer<Utf8>);

typedef ParseSemesterFunc = Pointer<SemesterResult> Function(Pointer<Utf8>);
typedef ParseSemester = Pointer<SemesterResult> Function(Pointer<Utf8>);

typedef ParseUserFunc = Pointer<UserResult> Function(Pointer<Utf8>);
typedef ParseUser = Pointer<UserResult> Function(Pointer<Utf8>);

typedef FreeCourseHourResultFunc = Void Function(Pointer<CourseHourResult>);
typedef FreeCourseHourResult = void Function(Pointer<CourseHourResult>);

typedef FreeSchoolYearResultFunc = Void Function(Pointer<SchoolYearResult>);
typedef FreeSchoolYearResult = void Function(Pointer<SchoolYearResult>);

typedef FreeSemesterResultFunc = Void Function(Pointer<SemesterResult>);
typedef FreeSemesterResult = void Function(Pointer<SemesterResult>);

typedef FreeUserResultFunc = Void Function(Pointer<UserResult>);
typedef FreeUserResult = void Function(Pointer<UserResult>);

typedef ParseRegistrationFunc =
    Pointer<RegistrationResult> Function(Pointer<Utf8>);
typedef ParseRegistration = Pointer<RegistrationResult> Function(Pointer<Utf8>);

typedef FreeRegistrationResultFunc = Void Function(Pointer<RegistrationResult>);
typedef FreeRegistrationResult = void Function(Pointer<RegistrationResult>);

typedef ParseRegistrationActionFunc =
    Pointer<RegistrationActionNative> Function(Pointer<Utf8>);
typedef ParseRegistrationAction =
    Pointer<RegistrationActionNative> Function(Pointer<Utf8>);

typedef FreeRegistrationActionResultFunc =
    Void Function(Pointer<RegistrationActionNative>);
typedef FreeRegistrationActionResult =
    void Function(Pointer<RegistrationActionNative>);

class NativeParser {
  static DynamicLibrary? _lib;

  static DynamicLibrary get _library {
    if (_lib != null) return _lib!;
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libnekkoFramework.so');
    } else {
      _lib = DynamicLibrary.process();
    }
    return _lib!;
  }

  // --- Cache Native Logic ---
  static String? _cachedCoursesJson;
  static String? _cachedHoursJson;

  static void clearCache() {
    _cachedCoursesJson = null;
    _cachedHoursJson = null;
  }

  static String getYyjsonVersion() {
    try {
      final func = _library.lookupFunction<GetVersionFunc, GetVersion>(
        'get_yyjson_version',
      );
      return func().toDartString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  // --- Registration Binding ---
  static List<SubjectRegistrationModel> parseRegistrationData(
    String jsonString,
  ) {
    try {
      final func = _library
          .lookupFunction<ParseRegistrationFunc, ParseRegistration>(
            'parse_registration_data',
          );
      final jsonPtr = jsonString.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      calloc.free(jsonPtr);

      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        final errorMsg = result.errorMessage.toDartString();
        debugPrint("Native Registration Error: $errorMsg");
        final freeFunc = _library
            .lookupFunction<FreeRegistrationResultFunc, FreeRegistrationResult>(
              'free_registration_result',
            );
        freeFunc(resultPtr);
        // Throwing exception so provider catches it
        throw Exception("Native Parse Error: $errorMsg");
      }

      List<SubjectRegistrationModel> subjects = [];
      if (result.data != nullptr) {
        final period = result.data.ref;
        final subjectsPtr = period.subjects;
        final count = period.subjectsCount;

        for (int i = 0; i < count; i++) {
          final sNative = subjectsPtr[i];

          List<CourseSubjectModel> courseSubjects = [];
          final csPtr = sNative.courseSubjects;
          final csCount = sNative.courseSubjectsCount;

          for (int j = 0; j < csCount; j++) {
            final csNative = csPtr[j];

            List<TimetableModel> timetables = [];
            final tPtr = csNative.timetables;
            final tCount = csNative.timetablesCount;

            for (int k = 0; k < tCount; k++) {
              final tNative = tPtr[k];
              timetables.add(
                TimetableModel(
                  id: tNative.id,
                  startDate: tNative.startDate,
                  endDate: tNative.endDate,
                  fromWeek: tNative.fromWeek,
                  toWeek: tNative.toWeek,
                  dayOfWeek: tNative.dayOfWeek,
                  startHour: tNative.startHour,
                  endHour: tNative.endHour,
                  roomName: tNative.roomName != nullptr
                      ? tNative.roomName.toDartString()
                      : '',
                  teacherName: tNative.teacherName != nullptr
                      ? tNative.teacherName.toDartString()
                      : '',
                ),
              );
            }

            courseSubjects.add(
              CourseSubjectModel(
                id: csNative.id,
                code: csNative.code != nullptr
                    ? csNative.code.toDartString()
                    : '',
                name: csNative.name != nullptr
                    ? csNative.name.toDartString()
                    : '',
                displayCode: csNative.displayCode != nullptr
                    ? csNative.displayCode.toDartString()
                    : '',
                numberStudent: csNative.numberStudent,
                maxStudent: csNative.maxStudent,
                isSelected: csNative.isSelected,
                isFull: csNative.isFull,
                isOverlap: csNative.isOverlap,
                credits: csNative.credits,
                status: csNative.status != nullptr
                    ? csNative.status.toDartString()
                    : '',
                timetables: timetables,
              ),
            );
          }

          subjects.add(
            SubjectRegistrationModel(
              subjectName: sNative.subjectName != nullptr
                  ? sNative.subjectName.toDartString()
                  : '',
              numberOfCredit: sNative.numberOfCredit,
              courseSubjects: courseSubjects,
            ),
          );
        }
      }

      final freeFunc = _library
          .lookupFunction<FreeRegistrationResultFunc, FreeRegistrationResult>(
            'free_registration_result',
          );
      freeFunc(resultPtr);
      return subjects;
    } catch (e) {
      debugPrint("Native Parse Error (Registration): $e");
      return [];
    }
  }

  static ({bool success, String message, int status}) parseRegistrationAction(
    String jsonString,
  ) {
    try {
      final func = _library
          .lookupFunction<ParseRegistrationActionFunc, ParseRegistrationAction>(
            'parse_registration_action',
          );
      final jsonPtr = jsonString.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      calloc.free(jsonPtr);

      final result = resultPtr.ref;
      final status = result.status;
      final message = result.message != nullptr
          ? result.message.toDartString()
          : '';

      final freeFunc = _library
          .lookupFunction<
            FreeRegistrationActionResultFunc,
            FreeRegistrationActionResult
          >('free_registration_action_result');
      freeFunc(resultPtr);

      // If status is 200, assume success.
      return (success: status == 200, message: message, status: status);
    } catch (e) {
      debugPrint("Native Action Parse Error: $e");
      return (success: false, message: "Native Error: $e", status: -1);
    }
  }

  // --- Notification Binding ---
  static List<NotificationNativeModel> generateNotifications(
    int semesterStartMillis,
  ) {
    if (_cachedCoursesJson == null || _cachedHoursJson == null) {
      debugPrint("Native Notif: Missing cached JSONs");
      return [];
    }
    final coursesJson = _cachedCoursesJson!;
    final hoursJson = _cachedHoursJson!;
    if (coursesJson.isEmpty || hoursJson.isEmpty) return [];

    try {
      final func = _library
          .lookupFunction<
            Pointer<NotificationResult> Function(
              Pointer<Utf8>,
              Pointer<Utf8>,
              Int64,
            ),
            Pointer<NotificationResult> Function(
              Pointer<Utf8>,
              Pointer<Utf8>,
              int,
            )
          >('generate_notifications');

      final freeFunc = _library
          .lookupFunction<
            Void Function(Pointer<NotificationResult>),
            void Function(Pointer<NotificationResult>)
          >('free_notification_result');

      final cPtr = coursesJson.toNativeUtf8();
      final hPtr = hoursJson.toNativeUtf8();

      Pointer<NotificationResult>? resultPtr;
      try {
        resultPtr = func(cPtr, hPtr, semesterStartMillis);

        if (resultPtr == nullptr) return [];

        final result = resultPtr.ref;
        if (result.errorMessage != nullptr) {
          debugPrint(
            "Native Notif Error: ${result.errorMessage.toDartString()}",
          );
          freeFunc(resultPtr);
          return [];
        }

        final List<NotificationNativeModel> list = [];
        final count = result.count;
        final items = result.notifications;

        for (int i = 0; i < count; i++) {
          final item = items[i];
          list.add(
            NotificationNativeModel(
              id: item.id,
              triggerTime: item.triggerTime,
              title: item.title != nullptr ? item.title.toDartString() : '',
              body: item.body != nullptr ? item.body.toDartString() : '',
            ),
          );
        }

        freeFunc(resultPtr);
        return list;
      } finally {
        malloc.free(cPtr);
        malloc.free(hPtr);
      }
    } catch (e) {
      debugPrint("Native Logic Error (Notif): $e");
      return [];
    }
  }

  static List<CourseModel> parseCourses(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    _cachedCoursesJson = jsonStr; // Cache input
    try {
      final func = _library.lookupFunction<ParseCoursesFunc, ParseCourses>(
        'parse_courses',
      );
      final freeFunc = _library
          .lookupFunction<FreeCourseResultFunc, FreeCourseResult>(
            'free_course_result',
          );

      final jsonPtr = jsonStr.toNativeUtf8();
      Pointer<CourseResult>? resultPtr;
      try {
        resultPtr = func(jsonPtr);

        if (resultPtr == nullptr) {
          return [];
        }

        final result = resultPtr.ref;
        if (result.errorMessage != nullptr) {
          print(
            "Native Parser Error (Courses): ${result.errorMessage.toDartString()}",
          );
          // Free result but strings are owned by jsonPtr so safe.
          // errorMessage is strdup'd so C++ frees it.
          freeFunc(resultPtr);
          return [];
        }

        final List<CourseModel> list = [];
        final count = result.count;
        final coursesPtr = result.courses;

        // Iterate and copy strings to Dart heap (Zero-Copy ends here)
        for (int i = 0; i < count; i++) {
          final cNative = coursesPtr[i];
          list.add(
            CourseModel(
              id: cNative.id,
              courseCode: cNative.courseCode != nullptr
                  ? cNative.courseCode.toDartString()
                  : '',
              courseName: cNative.courseName != nullptr
                  ? cNative.courseName.toDartString()
                  : '',
              classCode: cNative.classCode != nullptr
                  ? cNative.classCode.toDartString()
                  : '',
              className: cNative.className != nullptr
                  ? cNative.className.toDartString()
                  : '',
              dayOfWeek: cNative.dayOfWeek,
              startCourseHour: cNative.startCourseHour,
              endCourseHour: cNative.endCourseHour,
              room: cNative.room != nullptr ? cNative.room.toDartString() : '',
              building: cNative.building != nullptr
                  ? cNative.building.toDartString()
                  : '',
              campus: cNative.campus != nullptr
                  ? cNative.campus.toDartString()
                  : '',
              credits: cNative.credits,
              startDate: cNative.startDate,
              endDate: cNative.endDate,
              fromWeek: cNative.fromWeek,
              toWeek: cNative.toWeek,
              lecturerName: cNative.lecturerName != nullptr
                  ? cNative.lecturerName.toDartString()
                  : null,
              lecturerEmail: cNative.lecturerEmail != nullptr
                  ? cNative.lecturerEmail.toDartString()
                  : null,
              status: cNative.status != nullptr
                  ? cNative.status.toDartString()
                  : 'N/A',
              grade: cNative.hasGrade ? cNative.grade : null,
            ),
          );
        }

        freeFunc(resultPtr);
        return list;
      } finally {
        // Free JSON source buffer LAST.
        // C++ native strings were pointing into this buffer.
        malloc.free(jsonPtr);
      }
    } catch (e) {
      print("Native Logic Error (Courses): $e");
      return [];
    }
  }

  static List<ExamRoomModel> parseExamRooms(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final func = _library.lookupFunction<ParseExamRoomsFunc, ParseExamRooms>(
        'parse_exam_rooms',
      );
      final freeFunc = _library
          .lookupFunction<FreeExamRoomResultFunc, FreeExamRoomResult>(
            'free_exam_room_result',
          );

      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);

      if (resultPtr == nullptr) {
        print("Native parseExamRooms returned null");
        return [];
      }

      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        print(
          "Native Parser Error (ExamRooms): ${result.errorMessage.toDartString()}",
        );
        freeFunc(resultPtr);
        return [];
      }

      final List<ExamRoomModel> list = [];
      final count = result.count;
      final roomsPtr = result.rooms;

      for (int i = 0; i < count; i++) {
        final rNative = roomsPtr[i];
        list.add(
          ExamRoomModel(
            id: rNative.id,
            subjectName: rNative.subjectName != nullptr
                ? rNative.subjectName.toDartString()
                : '',
            examPeriodCode: rNative.examPeriodCode != nullptr
                ? rNative.examPeriodCode.toDartString()
                : '',
            examCode: rNative.examCode != nullptr
                ? rNative.examCode.toDartString()
                : null,
            studentCode: rNative.studentCode != nullptr
                ? rNative.studentCode.toDartString()
                : null,
            examDate: rNative.examDate > 0
                ? DateTime.fromMillisecondsSinceEpoch(rNative.examDate)
                : null,
            examTime: rNative.examTime != nullptr
                ? rNative.examTime.toDartString()
                : null,
            roomName: rNative.roomName != nullptr
                ? rNative.roomName.toDartString()
                : null,
            roomBuilding: rNative.roomBuilding != nullptr
                ? rNative.roomBuilding.toDartString()
                : null,
            examMethod: rNative.examMethod != nullptr
                ? rNative.examMethod.toDartString()
                : null,
            notes: rNative.notes != nullptr
                ? rNative.notes.toDartString()
                : null,
            numberExpectedStudent: rNative.numberExpectedStudent,
          ),
        );
      }

      freeFunc(resultPtr);
      return list;
    } catch (e) {
      print("Native Logic Error (ExamRooms): $e");
      return [];
    }
  }

  static List<ExamScheduleModel> parseExamSchedules(String jsonStr) {
    if (jsonStr.isEmpty) return [];

    try {
      final func = _library
          .lookupFunction<ParseExamDetailsFunc, ParseExamDetails>(
            'parse_exam_schedules',
          );
      final freeFunc = _library.lookupFunction<FreeResultFunc, FreeResult>(
        'free_exam_schedule_result',
      );

      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);

      if (resultPtr == nullptr) {
        print("Native parser returned null");
        return [];
      }

      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        print("Native Parser Error: ${result.errorMessage.toDartString()}");
        freeFunc(resultPtr);
        return [];
      }

      final List<ExamScheduleModel> list = [];
      final count = result.count;
      final schedulesPtr = result.schedules;

      for (int i = 0; i < count; i++) {
        final schNative = schedulesPtr[i];

        // Map ExamPeriods
        final List<ExamPeriodModel> periods = [];
        final pCount = schNative.examPeriodsCount;
        final pPtr = schNative.examPeriods;

        for (int j = 0; j < pCount; j++) {
          final pNative = pPtr[j];
          periods.add(
            ExamPeriodModel(
              id: pNative.id,
              examPeriodCode: pNative.examPeriodCode != nullptr
                  ? pNative.examPeriodCode.toDartString()
                  : '',
              name: pNative.name != nullptr ? pNative.name.toDartString() : '',
              startDate: pNative.startDate,
              endDate: pNative.endDate,
              numberOfExamDays: pNative.numberOfExamDays,
              bookingStatus: BookingStatusModel(
                id: pNative.bookingStatus.id,
                name: pNative.bookingStatus.name != nullptr
                    ? pNative.bookingStatus.name.toDartString()
                    : '',
              ),
            ),
          );
        }

        list.add(
          ExamScheduleModel(
            id: schNative.id,
            name: schNative.name != nullptr
                ? schNative.name.toDartString()
                : '',
            displayOrder: schNative.displayOrder,
            voided: schNative.voided,
            examPeriods: periods,
          ),
        );
      }

      freeFunc(resultPtr);
      return list;
    } catch (e) {
      print('Native Logic Error: $e');
      return [];
    }
  }

  static List<CourseHour> parseCourseHours(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    _cachedHoursJson = jsonStr; // Cache input
    try {
      final func = _library
          .lookupFunction<ParseCourseHoursFunc, ParseCourseHours>(
            'parse_course_hours',
          );
      final freeFunc = _library
          .lookupFunction<FreeCourseHourResultFunc, FreeCourseHourResult>(
            'free_course_hour_result',
          );
      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);
      if (resultPtr == nullptr) return [];
      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        freeFunc(resultPtr);
        return [];
      }
      final List<CourseHour> list = [];
      for (int i = 0; i < result.count; i++) {
        final h = result.hours[i];
        list.add(
          CourseHour(
            id: h.id,
            name: h.name != nullptr ? h.name.toDartString() : '',
            startString: h.startString != nullptr
                ? h.startString.toDartString()
                : '',
            endString: h.endString != nullptr ? h.endString.toDartString() : '',
            indexNumber: h.indexNumber,
          ),
        );
      }
      freeFunc(resultPtr);
      return list;
    } catch (e) {
      return [];
    }
  }

  static List<SchoolYearModel> parseSchoolYears(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final func = _library
          .lookupFunction<ParseSchoolYearsFunc, ParseSchoolYears>(
            'parse_school_years',
          );
      final freeFunc = _library
          .lookupFunction<FreeSchoolYearResultFunc, FreeSchoolYearResult>(
            'free_school_year_result',
          );
      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);
      if (resultPtr == nullptr) return [];
      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        freeFunc(resultPtr);
        return [];
      }
      final List<SchoolYearModel> list = [];
      for (int i = 0; i < result.count; i++) {
        final sy = result.years[i];
        List<SemesterModel> semesters = [];
        final sPtr = sy.semesters;
        for (int j = 0; j < sy.semestersCount; j++) {
          final s = sPtr[j];
          // Parse Register Periods
          List<SemesterRegisterPeriodModel> periods = [];
          final rpCount = s.registerPeriodsCount;
          final rpPtr = s.registerPeriods;
          if (rpPtr != nullptr && rpCount > 0) {
            for (int k = 0; k < rpCount; k++) {
              final rp = rpPtr[k];
              periods.add(
                SemesterRegisterPeriodModel(
                  id: rp.id,
                  name: rp.name != nullptr ? rp.name.toDartString() : '',
                  startRegisterTime: rp.startRegisterTime > 0
                      ? rp.startRegisterTime
                      : _parseDateString(
                          rp.startRegisterTimeString.address == 0
                              ? null
                              : rp.startRegisterTimeString.toDartString(),
                        ),
                  endRegisterTime: rp.endRegisterTime > 0
                      ? rp.endRegisterTime
                      : _parseDateString(
                          rp.endRegisterTimeString.address == 0
                              ? null
                              : rp.endRegisterTimeString.toDartString(),
                        ),
                  endUnRegisterTime: rp.endUnRegisterTime > 0
                      ? rp.endUnRegisterTime
                      : _parseDateString(
                          rp.endUnRegisterTimeString.address == 0
                              ? null
                              : rp.endUnRegisterTimeString.toDartString(),
                        ),
                ),
              );
            }
          }

          semesters.add(
            SemesterModel(
              id: s.id,
              semesterCode: s.semesterCode != nullptr
                  ? s.semesterCode.toDartString()
                  : '',
              semesterName: s.semesterName != nullptr
                  ? s.semesterName.toDartString()
                  : '',
              startDate: s.startDate,
              endDate: s.endDate,
              isCurrent: s.isCurrent,
              ordinalNumbers: s.ordinalNumbers,
              registerPeriods: periods,
            ),
          );
        }
        list.add(
          SchoolYearModel(
            id: sy.id,
            name: sy.name != nullptr ? sy.name.toDartString() : '',
            code: sy.code != nullptr ? sy.code.toDartString() : '',
            year: sy.year,
            current: sy.current,
            startDate: sy.startDate,
            endDate: sy.endDate,
            displayName: sy.displayName != nullptr
                ? sy.displayName.toDartString()
                : '',
            semesters: semesters,
          ),
        );
      }
      freeFunc(resultPtr);
      return list;
    } catch (e) {
      return [];
    }
  }

  static SemesterModel? parseSemester(String jsonStr) {
    if (jsonStr.isEmpty) return null;
    try {
      final func = _library.lookupFunction<ParseSemesterFunc, ParseSemester>(
        'parse_semester',
      );
      final freeFunc = _library
          .lookupFunction<FreeSemesterResultFunc, FreeSemesterResult>(
            'free_semester_result',
          );
      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);
      if (resultPtr == nullptr) return null;
      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        freeFunc(resultPtr);
        return null;
      }
      SemesterModel? sm;
      if (result.semester != nullptr) {
        final s = result.semester.ref;

        // Parse periods for single semester too if needed
        List<SemesterRegisterPeriodModel> periods = [];
        final rpCount = s.registerPeriodsCount;
        final rpPtr = s.registerPeriods;
        if (rpPtr != nullptr && rpCount > 0) {
          for (int k = 0; k < rpCount; k++) {
            final rp = rpPtr[k];
            periods.add(
              SemesterRegisterPeriodModel(
                id: rp.id,
                name: rp.name != nullptr ? rp.name.toDartString() : '',
                startRegisterTime: rp.startRegisterTime > 0
                    ? rp.startRegisterTime
                    : _parseDateString(
                        rp.startRegisterTimeString.address == 0
                            ? null
                            : rp.startRegisterTimeString.toDartString(),
                      ),
                endRegisterTime: rp.endRegisterTime > 0
                    ? rp.endRegisterTime
                    : _parseDateString(
                        rp.endRegisterTimeString.address == 0
                            ? null
                            : rp.endRegisterTimeString.toDartString(),
                      ),
                endUnRegisterTime: rp.endUnRegisterTime > 0
                    ? rp.endUnRegisterTime
                    : _parseDateString(
                        rp.endUnRegisterTimeString.address == 0
                            ? null
                            : rp.endUnRegisterTimeString.toDartString(),
                      ),
              ),
            );
          }
        }

        sm = SemesterModel(
          id: s.id,
          semesterCode: s.semesterCode != nullptr
              ? s.semesterCode.toDartString()
              : '',
          semesterName: s.semesterName != nullptr
              ? s.semesterName.toDartString()
              : '',
          startDate: s.startDate,
          endDate: s.endDate,
          isCurrent: s.isCurrent,
          ordinalNumbers: s.ordinalNumbers,
          registerPeriods: periods,
        );
      }
      freeFunc(resultPtr);
      return sm;
    } catch (e) {
      return null;
    }
  }

  static UserModel? parseUser(String jsonStr) {
    if (jsonStr.isEmpty) return null;
    try {
      final func = _library.lookupFunction<ParseUserFunc, ParseUser>(
        'parse_user',
      );
      final freeFunc = _library
          .lookupFunction<FreeUserResultFunc, FreeUserResult>(
            'free_user_result',
          );
      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);
      if (resultPtr == nullptr) return null;
      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        freeFunc(resultPtr);
        return null;
      }
      UserModel? user;
      if (result.user != nullptr) {
        final u = result.user.ref;
        user = UserModel(
          studentId: u.studentId != nullptr ? u.studentId.toDartString() : '',
          fullName: u.fullName != nullptr ? u.fullName.toDartString() : '',
          email: u.email != nullptr ? u.email.toDartString() : '',
          id: u.id,
          profileImageUrl: null,
        );
      }
      freeFunc(resultPtr);
      return user;
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? parseToken(String jsonStr) {
    if (jsonStr.isEmpty) return null;
    try {
      final func = _library.lookupFunction<ParseTokenFunc, ParseToken>(
        'parse_token',
      );
      final freeFunc = _library
          .lookupFunction<FreeTokenResultFunc, FreeTokenResult>(
            'free_token_result',
          );
      final jsonPtr = jsonStr.toNativeUtf8();
      final resultPtr = func(jsonPtr);
      malloc.free(jsonPtr);
      if (resultPtr == nullptr) return null;
      final result = resultPtr.ref;
      if (result.errorMessage != nullptr) {
        freeFunc(resultPtr);
        return null;
      }

      Map<String, dynamic>? map;
      if (result.token != nullptr) {
        final t = result.token.ref;
        map = {
          'access_token': t.access_token != nullptr
              ? t.access_token.toDartString()
              : null,
          'token_type': t.token_type != nullptr
              ? t.token_type.toDartString()
              : null,
          'refresh_token': t.refresh_token != nullptr
              ? t.refresh_token.toDartString()
              : null,
          'scope': t.scope != nullptr ? t.scope.toDartString() : null,
          'expires_in': t.expires_in,
        };
      }
      freeFunc(resultPtr);
      return map;
    } catch (e) {
      return null;
    }
  }

  static int _parseDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 0;
    try {
      return DateTime.parse(dateStr).millisecondsSinceEpoch;
    } catch (_) {
      try {
        // Handle dd/MM/yyyy HH:mm or dd-MM-yyyy HH:mm
        // Normalize - to /
        final normalized = dateStr.replaceAll('-', '/');
        final parts = normalized.split(' ');
        final dateParts = parts[0].split('/');

        if (dateParts.length == 3) {
          final day = int.tryParse(dateParts[0]) ?? 1;
          final month = int.tryParse(dateParts[1]) ?? 1;
          final year = int.tryParse(dateParts[2]) ?? 1970;

          int hour = 0;
          int minute = 0;

          if (parts.length > 1) {
            final timeParts = parts[1].split(':');
            if (timeParts.length >= 2) {
              hour = int.tryParse(timeParts[0]) ?? 0;
              minute = int.tryParse(timeParts[1]) ?? 0;
            }
          }
          // Year must be 4 digits usually. if < 100 assume 20xx? No, TLU uses 4 digits.
          return DateTime(
            year,
            month,
            day,
            hour,
            minute,
          ).millisecondsSinceEpoch;
        }
        return 0;
      } catch (e) {
        return 0;
      }
    }
  }
}
