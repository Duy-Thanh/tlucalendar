import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/registration/data/datasources/registration_remote_data_source.dart';
import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';
import 'package:tlucalendar/features/registration/domain/repositories/registration_repository.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  final RegistrationRemoteDataSource remoteDataSource;

  RegistrationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<SubjectRegistration>>> getRegistrationData(
    String personId,
    String periodId,
  ) async {
    try {
      final subjects = await remoteDataSource.getRegistrationData(
        personId,
        periodId,
      );
      return Right(subjects);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure("Repository Error"));
    }
  }

  @override
  Future<Either<Failure, void>> registerCourse(
    String personId,
    String periodId,
    String payload,
  ) async {
    try {
      await remoteDataSource.registerCourse(personId, periodId, payload);
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure("Repository Error"));
    }
  }

  @override
  Future<Either<Failure, void>> cancelCourse(
    String personId,
    String periodId,
    String payload,
  ) async {
    try {
      await remoteDataSource.cancelCourse(personId, periodId, payload);
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure("Repository Error"));
    }
  }
}
