import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/usecases/usecase.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';
import 'package:tlucalendar/features/exam/domain/repositories/exam_repository.dart';

class GetExamRoomsUseCase
    implements UseCase<List<ExamRoom>, GetExamRoomsParams> {
  final ExamRepository repository;

  GetExamRoomsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ExamRoom>>> call(
    GetExamRoomsParams params,
  ) async {
    return await repository.getExamRooms(
      semesterId: params.semesterId,
      scheduleId: params.scheduleId,
      round: params.round,
      accessToken: params.accessToken,
      rawToken: params.rawToken,
    );
  }
}

class GetExamRoomsParams extends Equatable {
  final int semesterId;
  final int scheduleId;
  final int round;
  final String accessToken;
  final String? rawToken;

  const GetExamRoomsParams({
    required this.semesterId,
    required this.scheduleId,
    required this.round,
    required this.accessToken,
    this.rawToken,
  });

  @override
  List<Object> get props => [
    semesterId,
    scheduleId,
    round,
    accessToken,
    if (rawToken != null) rawToken!,
  ];
}
