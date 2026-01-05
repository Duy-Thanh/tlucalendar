import 'package:tlucalendar/features/schedule/domain/entities/semester_register_period.dart';

class SemesterRegisterPeriodModel extends SemesterRegisterPeriod {
  const SemesterRegisterPeriodModel({
    required super.id,
    required super.name,
    required super.startRegisterTime,
    required super.endRegisterTime,
    required super.endUnRegisterTime,
  });

  factory SemesterRegisterPeriodModel.fromJson(Map<String, dynamic> json) {
    return SemesterRegisterPeriodModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      startRegisterTime: json['startRegisterTime'] as int? ?? 0,
      endRegisterTime: json['endRegisterTime'] as int? ?? 0,
      endUnRegisterTime: json['endUnRegisterTime'] as int? ?? 0,
    );
  }
}
