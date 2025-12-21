import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';

class SchoolYearModel extends SchoolYear {
  const SchoolYearModel({
    required int id,
    required String name,
    required String code,
    required int year,
    required bool current,
    required int startDate,
    required int endDate,
    required String displayName,
    required List<SemesterModel> semesters,
  }) : super(
         id: id,
         name: name,
         code: code,
         year: year,
         current: current,
         startDate: startDate,
         endDate: endDate,
         displayName: displayName,
         semesters: semesters,
       );

  factory SchoolYearModel.fromJson(Map<String, dynamic> json) {
    var semestersList = json['semesters'] as List?;
    return SchoolYearModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      year: json['year'] ?? 0,
      current: json['current'] ?? false,
      startDate: json['startDate'] ?? 0,
      endDate: json['endDate'] ?? 0,
      displayName: json['displayName'] ?? '',
      semesters: semestersList != null
          ? semestersList.map((item) => SemesterModel.fromJson(item)).toList()
          : [],
    );
  }
}
