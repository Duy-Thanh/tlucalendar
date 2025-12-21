import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/usecases/usecase.dart';
import 'package:tlucalendar/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase implements UseCase<String, LoginParams> {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(LoginParams params) async {
    return await repository.login(params.studentCode, params.password);
  }
}

class LoginParams extends Equatable {
  final String studentCode;
  final String password;

  const LoginParams({required this.studentCode, required this.password});

  @override
  List<Object> get props => [studentCode, password];
}
