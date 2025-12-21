import 'package:equatable/equatable.dart';

class CourseHour extends Equatable {
  final int id;
  final String name; // "Tiết 1"
  final String startString; // "07:00"
  final String endString; // "07:50"
  final int indexNumber; // 1

  const CourseHour({
    required this.id,
    required this.name,
    required this.startString,
    required this.endString,
    required this.indexNumber,
  });

  @override
  List<Object?> get props => [id, name, startString, endString, indexNumber];
}
