import 'package:equatable/equatable.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_period.dart';

class ExamSchedule extends Equatable {
  final int id;
  final String name; // Name of the register period (e.g. "Đợt 1")
  final int displayOrder;
  final bool voided;
  final List<ExamPeriod> examPeriods;

  const ExamSchedule({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.voided,
    required this.examPeriods,
  });

  @override
  List<Object?> get props => [id, name, displayOrder, voided, examPeriods];
}
