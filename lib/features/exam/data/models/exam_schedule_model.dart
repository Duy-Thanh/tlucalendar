import 'package:tlucalendar/features/exam/domain/entities/exam_period.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_schedule.dart';

class ExamScheduleModel extends ExamSchedule {
  const ExamScheduleModel({
    required super.id,
    required super.name,
    required super.displayOrder,
    required super.voided,
    required super.examPeriods,
  });

  factory ExamScheduleModel.fromJson(Map<String, dynamic> json) {
    return ExamScheduleModel(
      id: json['id'] ?? 0,
      voided: json['voided'] ?? false,
      name: json['name'] ?? '',
      displayOrder: json['displayOrder'] ?? 0,
      examPeriods:
          (json['examPeriods'] as List<dynamic>?)
              ?.map((e) => ExamPeriodModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ExamPeriodModel extends ExamPeriod {
  const ExamPeriodModel({
    required super.id,
    required super.examPeriodCode,
    required super.name,
    required super.startDate,
    required super.endDate,
    required super.numberOfExamDays,
    required super.bookingStatus,
  });

  factory ExamPeriodModel.fromJson(Map<String, dynamic> json) {
    return ExamPeriodModel(
      id: json['id'] ?? 0,
      examPeriodCode: json['examPeriodCode'] ?? '',
      name: json['name'] ?? '',
      startDate: json['startDate'] ?? 0,
      endDate: json['endDate'] ?? 0,
      numberOfExamDays: json['numberOfExamDays'] ?? 0,
      bookingStatus: BookingStatusModel.fromJson(json['bookingStatus'] ?? {}),
    );
  }
}

class BookingStatusModel extends BookingStatus {
  const BookingStatusModel({required super.id, required super.name});

  factory BookingStatusModel.fromJson(Map<String, dynamic> json) {
    return BookingStatusModel(id: json['id'] ?? 0, name: json['name'] ?? '');
  }
}
