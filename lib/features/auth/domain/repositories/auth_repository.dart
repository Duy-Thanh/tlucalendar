import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  /// Login with student code and password. Returns access token.
  Future<Either<Failure, String>> login(String studentCode, String password);

  /// Get current user details using access token
  Future<Either<Failure, User>> getCurrentUser(String accessToken);

  /// Check if token is valid
  Future<bool> isTokenValid(String accessToken);

  /// Get saved credentials (for auto-login)
  Future<Either<Failure, Map<String, String>>> getSavedCredentials();

  /// Save credentials
  Future<void> saveCredentials(String studentCode, String password);

  /// Clear credentials
  Future<void> clearCredentials();
}
