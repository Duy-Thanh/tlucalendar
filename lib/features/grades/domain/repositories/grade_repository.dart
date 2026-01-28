import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/grades/domain/entities/student_mark.dart';

abstract class GradeRepository {
  Future<Either<Failure, List<StudentMark>>> getGrades(String accessToken);
}
