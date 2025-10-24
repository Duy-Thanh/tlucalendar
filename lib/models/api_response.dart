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

// School Year / Semester Response
class SchoolYearResponse {
  final List<SchoolYear> content;
  final bool last;
  final int totalElements;
  final int totalPages;

  SchoolYearResponse({
    required this.content,
    required this.last,
    required this.totalElements,
    required this.totalPages,
  });

  factory SchoolYearResponse.fromJson(Map<String, dynamic> json) {
    var contentList = json['content'] as List;
    return SchoolYearResponse(
      content: contentList.map((item) => SchoolYear.fromJson(item)).toList(),
      last: json['last'] ?? true,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}

class SchoolYear {
  final int id;
  final String name;
  final String code;
  final int year;
  final bool current;
  final int startDate;
  final int endDate;
  final String displayName;
  final List<Semester> semesters;

  SchoolYear({
    required this.id,
    required this.name,
    required this.code,
    required this.year,
    required this.current,
    required this.startDate,
    required this.endDate,
    required this.displayName,
    required this.semesters,
  });

  factory SchoolYear.fromJson(Map<String, dynamic> json) {
    var semestersList = json['semesters'] as List?;
    return SchoolYear(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      year: json['year'] ?? 0,
      current: json['current'] ?? false,
      startDate: json['startDate'] ?? 0,
      endDate: json['endDate'] ?? 0,
      displayName: json['displayName'] ?? '',
      semesters: semestersList != null 
        ? semestersList.map((item) => Semester.fromJson(item)).toList()
        : [],
    );
  }
}

class Semester {
  final int id;
  final String semesterCode;
  final String semesterName;
  final int startDate;
  final int endDate;
  final bool isCurrent;
  final List<SemesterRegisterPeriod> semesterRegisterPeriods;

  Semester({
    required this.id,
    required this.semesterCode,
    required this.semesterName,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.semesterRegisterPeriods,
  });

  factory Semester.fromJson(Map<String, dynamic> json) {
    var periodsList = json['semesterRegisterPeriods'] as List?;
    return Semester(
      id: json['id'] ?? 0,
      semesterCode: json['semesterCode'] ?? '',
      semesterName: json['semesterName'] ?? '',
      startDate: json['startDate'] ?? 0,
      endDate: json['endDate'] ?? 0,
      isCurrent: json['isCurrent'] ?? false,
      semesterRegisterPeriods: periodsList != null
        ? periodsList.map((item) => SemesterRegisterPeriod.fromJson(item)).toList()
        : [],
    );
  }
}

class SemesterRegisterPeriod {
  final int id;
  final String name;
  final int displayOrder;

  SemesterRegisterPeriod({
    required this.id,
    required this.name,
    required this.displayOrder,
  });

  factory SemesterRegisterPeriod.fromJson(Map<String, dynamic> json) {
    return SemesterRegisterPeriod(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      displayOrder: json['displayOrder'] ?? 0,
    );
  }
}
