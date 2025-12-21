import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';

class SemesterModel extends Semester {
  const SemesterModel({
    required int id,
    required String semesterCode,
    required String semesterName,
    required int startDate,
    required int endDate,
    required bool isCurrent,
    int? ordinalNumbers,
  }) : super(
         id: id,
         semesterCode: semesterCode,
         semesterName: semesterName,
         startDate: startDate,
         endDate: endDate,
         isCurrent: isCurrent,
         ordinalNumbers: ordinalNumbers,
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
    );
  }
}
