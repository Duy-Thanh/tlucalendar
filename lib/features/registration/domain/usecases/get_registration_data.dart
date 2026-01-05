import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';
import 'package:tlucalendar/features/registration/domain/repositories/registration_repository.dart';

class GetRegistrationData {
  final RegistrationRepository repository;

  GetRegistrationData(this.repository);

  Future<Either<Failure, List<SubjectRegistration>>> call(
    String personId,
    String periodId,
  ) async {
    return await repository.getRegistrationData(personId, periodId);
  }
}
