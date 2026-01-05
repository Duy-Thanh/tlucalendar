import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_register_period_model.dart';

class SemesterModel extends Semester {
  const SemesterModel({
    required int id,
    required String semesterCode,
    required String semesterName,
    required int startDate,
    required int endDate,
    required bool isCurrent,
    int? ordinalNumbers,
    List<SemesterRegisterPeriodModel>? registerPeriods,
  }) : super(
         id: id,
         semesterCode: semesterCode,
         semesterName: semesterName,
         startDate: startDate,
         endDate: endDate,
         isCurrent: isCurrent,
         ordinalNumbers: ordinalNumbers,
         registerPeriods: registerPeriods,
       );

  factory SemesterModel.fromJson(Map<String, dynamic> json) {
    return SemesterModel(
      id: json['id'] ?? 0,
      semesterCode: json['semesterCode'] ?? '',
      semesterName: json['semesterName'] ?? '',
      startDate: json['startDate'] ?? 0,
      endDate: json['endDate'] ?? 0,
      isCurrent: json['isCurrent'] ?? false,
      ordinalNumbers: json['ordinalNumbers'],
      registerPeriods: json['semesterRegisterPeriods'] != null
          ? (json['semesterRegisterPeriods'] as List)
                .map((e) => SemesterRegisterPeriodModel.fromJson(e))
                .toList()
          : [],
    );
  }
}
