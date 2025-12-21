import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String studentId;
  final String fullName;
  final String email;
  final String? profileImageUrl;

  const User({
    required this.studentId,
    required this.fullName,
    required this.email,
    this.profileImageUrl,
  });

  @override
  List<Object?> get props => [studentId, fullName, email, profileImageUrl];
}
