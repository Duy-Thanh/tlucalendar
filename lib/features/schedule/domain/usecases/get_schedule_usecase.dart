import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/usecases/usecase.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/schedule/domain/repositories/schedule_repository.dart';

class GetScheduleUseCase implements UseCase<List<Course>, GetScheduleParams> {
  final ScheduleRepository repository;

  GetScheduleUseCase(this.repository);

  @override
  Future<Either<Failure, List<Course>>> call(GetScheduleParams params) async {
    return await repository.getCourses(params.semesterId, params.accessToken);
  }
}

class GetScheduleParams extends Equatable {
  final int semesterId;
  final String accessToken;

  const GetScheduleParams({
    required this.semesterId,
    required this.accessToken,
  });

  @override
  List<Object> get props => [semesterId, accessToken];
}
