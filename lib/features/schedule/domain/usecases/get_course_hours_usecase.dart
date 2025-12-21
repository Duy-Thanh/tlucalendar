import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/domain/repositories/schedule_repository.dart';

class GetCourseHoursUseCase {
  final ScheduleRepository repository;

  GetCourseHoursUseCase(this.repository);

  Future<Either<Failure, List<CourseHour>>> call(String accessToken) async {
    return await repository.getCourseHours(accessToken);
  }
}
