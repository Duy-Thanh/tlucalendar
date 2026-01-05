import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int? id;
  final String studentId;
  final String fullName;
  final String email;
  final String? profileImageUrl;

  const User({
    this.id,
    required this.studentId,
    required this.fullName,
    required this.email,
    this.profileImageUrl,
  });

  @override
  List<Object?> get props => [id, studentId, fullName, email, profileImageUrl];
}
