import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/grades/data/datasources/grade_remote_data_source.dart';
import 'package:tlucalendar/features/grades/domain/entities/student_mark.dart';
import 'package:tlucalendar/features/grades/domain/repositories/grade_repository.dart';

class GradeRepositoryImpl implements GradeRepository {
  final GradeRemoteDataSource remoteDataSource;

  GradeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<StudentMark>>> getGrades(
    String accessToken,
  ) async {
    try {
      final grades = await remoteDataSource.getGrades(accessToken);
      return Right(grades);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure("Repository Error"));
    }
  }
}
