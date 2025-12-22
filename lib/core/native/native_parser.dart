import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:tlucalendar/features/exam/data/models/exam_schedule_model.dart';
import 'package:tlucalendar/features/exam/data/models/exam_room_model.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_period.dart';

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

// --- Function Signatures ---

typedef ParseExamDetailsFunc =
    Pointer<ExamScheduleResult> Function(Pointer<Utf8>);
typedef ParseExamDetails = Pointer<ExamScheduleResult> Function(Pointer<Utf8>);

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
}
