class LoginResponse {
  final String accessToken;
  final String tokenType;
  final String refreshToken;
  final int expiresIn;
  final String scope;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.refreshToken,
    required this.expiresIn,
    required this.scope,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
      scope: json['scope'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'scope': scope,
    };
  }
}

class TluUser {
  final int id;
  final String displayName;
  final String username;
  final String email;
  final bool active;
  final Person? person;
  final List<UserRole> roles;

  TluUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
    required this.active,
    this.person,
    required this.roles,
  });

  factory TluUser.fromJson(Map<String, dynamic> json) {
    return TluUser(
      id: json['id'] ?? 0,
      displayName: json['displayName'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      active: json['active'] ?? false,
      person: json['person'] != null ? Person.fromJson(json['person']) : null,
      roles: (json['roles'] as List<dynamic>?)
              ?.map((r) => UserRole.fromJson(r))
              .toList() ??
          [],
    );
  }
}

class Person {
  final int id;
  final String firstName;
  final String lastName;
  final String displayName;
  final String? birthDateString;
  final String birthPlace;
  final String gender;
  final String phoneNumber;
  final String idNumber;
  final String email;
  final List<Address> address;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.birthDateString,
    required this.birthPlace,
    required this.gender,
    required this.phoneNumber,
    required this.idNumber,
    required this.email,
    required this.address,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      displayName: json['displayName'] ?? '',
      birthDateString: json['birthDateString'],
      birthPlace: json['birthPlace'] ?? '',
      gender: json['gender'] ?? 'M',
      phoneNumber: json['phoneNumber'] ?? '',
      idNumber: json['idNumber'] ?? '',
      email: json['email'] ?? '',
      address: (json['address'] as List<dynamic>?)
              ?.map((a) => Address.fromJson(a))
              .toList() ??
          [],
    );
  }
}

class Address {
  final int id;
  final String address;
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] ?? 0,
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class UserRole {
  final int id;
  final String name;
  final String authority;

  UserRole({
    required this.id,
    required this.name,
    required this.authority,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      authority: json['authority'] ?? '',
    );
  }
}
