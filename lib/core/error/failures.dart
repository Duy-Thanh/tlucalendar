import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class CachedDataFailure<T> extends Failure {
  final T data;
  const CachedDataFailure(this.data, [String message = 'Dữ liệu cũ (Offline)'])
    : super(message);

  @override
  List<Object?> get props => [message, data];
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
