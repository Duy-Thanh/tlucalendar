import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:tlucalendar/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tlucalendar/features/auth/domain/entities/user.dart';
import 'package:tlucalendar/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, String>> login(
    String studentCode,
    String password,
  ) async {
    try {
      final token = await remoteDataSource.login(studentCode, password);
      await localDataSource.cacheAccessToken(token);
      await localDataSource.saveCredentials(studentCode, password);
      return Right(token);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser(String accessToken) async {
    try {
      final userModel = await remoteDataSource.getCurrentUser(accessToken);
      return Right(userModel);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<bool> isTokenValid(String accessToken) async {
    // Current implementation doesn't have a specific validate endpoint,
    // but we can try to get user.
    try {
      await remoteDataSource.getCurrentUser(accessToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> getSavedCredentials() async {
    try {
      final result = await localDataSource.getCredentials();
      return Right(result);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<void> saveCredentials(String studentCode, String password) async {
    await localDataSource.saveCredentials(studentCode, password);
  }

  @override
  Future<void> clearCredentials() async {
    await localDataSource.clearCredentials();
    await localDataSource.clearCache();
  }
}
