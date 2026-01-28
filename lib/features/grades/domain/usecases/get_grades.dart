import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/usecases/usecase.dart';
import 'package:tlucalendar/features/grades/domain/entities/student_mark.dart';
import 'package:tlucalendar/features/grades/domain/repositories/grade_repository.dart';

class GetGradesParams extends Equatable {
  final String accessToken;
  const GetGradesParams({required this.accessToken});
  @override
  List<Object?> get props => [accessToken];
}

class GetGrades implements UseCase<List<StudentMark>, GetGradesParams> {
  final GradeRepository repository;

  GetGrades(this.repository);

  @override
  Future<Either<Failure, List<StudentMark>>> call(
    GetGradesParams params,
  ) async {
    return await repository.getGrades(params.accessToken);
  }
}
