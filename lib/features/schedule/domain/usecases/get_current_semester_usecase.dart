import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/features/schedule/domain/repositories/schedule_repository.dart';

class GetCurrentSemesterUseCase {
  final ScheduleRepository repository;

  GetCurrentSemesterUseCase(this.repository);

  Future<Either<Failure, Semester>> call(String accessToken) async {
    return await repository.getCurrentSemester(accessToken);
  }
}
