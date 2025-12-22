import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:tlucalendar/features/exam/data/models/exam_schedule_model.dart';

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

// --- Function Signatures ---

typedef ParseExamDetailsFunc =
    Pointer<ExamScheduleResult> Function(Pointer<Utf8>);
typedef ParseExamDetails = Pointer<ExamScheduleResult> Function(Pointer<Utf8>);

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
