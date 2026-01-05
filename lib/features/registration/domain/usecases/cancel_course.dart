import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/registration/domain/repositories/registration_repository.dart';

class CancelCourse {
  final RegistrationRepository repository;

  CancelCourse(this.repository);

  Future<Either<Failure, void>> call(
    String personId,
    String periodId,
    String payload,
  ) async {
    return await repository.cancelCourse(personId, periodId, payload);
  }
}
