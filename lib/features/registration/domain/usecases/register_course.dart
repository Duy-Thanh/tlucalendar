import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/registration/domain/repositories/registration_repository.dart';

class RegisterCourse {
  final RegistrationRepository repository;

  RegisterCourse(this.repository);

  Future<Either<Failure, void>> call(
    String personId,
    String periodId,
    String payload,
  ) async {
    return await repository.registerCourse(personId, periodId, payload);
  }
}
