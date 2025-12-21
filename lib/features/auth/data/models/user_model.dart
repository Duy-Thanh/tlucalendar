import 'package:tlucalendar/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.studentId,
    required super.fullName,
    required super.email,
    super.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      studentId: json['username'] ?? '',
      fullName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      // TLU API doesn't standardly return profile image here, so null
      profileImageUrl: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'username': studentId, 'displayName': fullName, 'email': email};
  }
}
