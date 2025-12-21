import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/repositories/schedule_repository.dart';

class GetSchoolYearsUseCase {
  final ScheduleRepository repository;

  GetSchoolYearsUseCase(this.repository);

  Future<Either<Failure, List<SchoolYear>>> call(String accessToken) async {
    return await repository.getSchoolYears(accessToken);
  }
}
