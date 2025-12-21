import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/auth/domain/entities/user.dart';
import 'package:tlucalendar/features/auth/domain/repositories/auth_repository.dart';

class GetUserUseCase {
  final AuthRepository repository;

  GetUserUseCase(this.repository);

  Future<Either<Failure, User>> call(String accessToken) async {
    return await repository.getCurrentUser(accessToken);
  }
}
