import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/usecases/usecase.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_schedule.dart';
import 'package:tlucalendar/features/exam/domain/repositories/exam_repository.dart';

class GetExamSchedulesUseCase
    implements UseCase<List<ExamSchedule>, GetExamSchedulesParams> {
  final ExamRepository repository;

  GetExamSchedulesUseCase(this.repository);

  @override
  Future<Either<Failure, List<ExamSchedule>>> call(
    GetExamSchedulesParams params,
  ) async {
    return await repository.getExamSchedules(
      params.semesterId,
      params.accessToken,
      params.rawToken,
    );
  }
}

class GetExamSchedulesParams extends Equatable {
  final int semesterId;
  final String accessToken;
  final Map<String, dynamic>? rawToken;

  const GetExamSchedulesParams({
    required this.semesterId,
    required this.accessToken,
    this.rawToken,
  });

  @override
  List<Object> get props => [
    semesterId,
    accessToken,
    if (rawToken != null) rawToken!,
  ];
}
