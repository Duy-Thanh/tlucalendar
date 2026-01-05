import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';

abstract class RegistrationRepository {
  Future<Either<Failure, List<SubjectRegistration>>> getRegistrationData(
    String personId,
    String periodId,
  );

  Future<Either<Failure, void>> registerCourse(
    String personId,
    String periodId,
    String payload,
  );

  Future<Either<Failure, void>> cancelCourse(
    String personId,
    String periodId,
    String payload,
  );
}
