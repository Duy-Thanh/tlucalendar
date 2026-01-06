import 'package:tlucalendar/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    super.id,
    required super.studentId,
    required super.fullName,
    required super.email,
    super.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Robust parsing for 'person' object
    final personObj = json['person'] ?? json['Person'];
    int? parsedId;
    if (personObj != null) {
      parsedId = personObj['id'] ?? personObj['Id'] ?? personObj['ID'];
    }

    // Robust parsing for 'id' at root if person is missing (fallback)
    if (parsedId == null) {
      parsedId = json['id'] ?? json['Id'];
    }

    return UserModel(
      id: parsedId,
      studentId: json['username'] ?? json['Username'] ?? '',
      fullName: json['displayName'] ?? json['DisplayName'] ?? '',
      email: json['email'] ?? json['Email'] ?? '',
      profileImageUrl: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': studentId,
      'displayName': fullName,
      'email': email,
      'person': id != null ? {'id': id} : null,
    };
  }
}
