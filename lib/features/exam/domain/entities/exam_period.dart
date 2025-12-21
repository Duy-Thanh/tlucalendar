import 'package:equatable/equatable.dart';

class BookingStatus extends Equatable {
  final int id;
  final String name;

  const BookingStatus({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class ExamPeriod extends Equatable {
  final int id;
  final String examPeriodCode;
  final String name;
  final int startDate; // ms since epoch
  final int endDate; // ms since epoch
  final int numberOfExamDays;
  final BookingStatus bookingStatus;

  const ExamPeriod({
    required this.id,
    required this.examPeriodCode,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.numberOfExamDays,
    required this.bookingStatus,
  });

  @override
  List<Object?> get props => [id, examPeriodCode, name, startDate, endDate];
}
