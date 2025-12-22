class RegisterPeriod {
  final int id;
  final bool voided;
  final SemesterDto semester;
  final String name;
  final int displayOrder;
  final List<dynamic> examPeriods;

  RegisterPeriod({
    required this.id,
    required this.voided,
    required this.semester,
    required this.name,
    required this.displayOrder,
    required this.examPeriods,
  });
}

class SemesterDto {
  final int id;
  final String semesterCode;
  final String semesterName;
  final int startDate;
  final int endDate;
  final bool isCurrent;
  final List<dynamic> semesterRegisterPeriods;

  SemesterDto({
    required this.id,
    required this.semesterCode,
    required this.semesterName,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.semesterRegisterPeriods,
  });
}

class StudentExamRoom {
  final int id;
  final int status;
  final String? examCode;
  final int? examCodeNumber;
  final String? markingCode;
  final String examPeriodCode;
  final String subjectName;
  final String? studentCode;
  final int examRound;
  final ExamRoomDetail? examRoom;

  StudentExamRoom({
    required this.id,
    required this.status,
    this.examCode,
    this.examCodeNumber,
    this.markingCode,
    required this.examPeriodCode,
    required this.subjectName,
    this.studentCode,
    required this.examRound,
    this.examRoom,
  });
}

class ExamRoomDetail {
  final int id;
  final String roomCode;
  final int? duration;
  final int? examDate;
  final String? examDateString;
  final int? numberExpectedStudent;
  final String? semesterName;
  final String? courseYearName;
  final String? registerPeriodName;
  final ExamHour? examHour;
  final Room? room;
  final String? examCode;
  final String? studentCode;
  final String? markingCode;
  final String? subjectName;
  final int? status;

  ExamRoomDetail({
    required this.id,
    required this.roomCode,
    this.duration,
    this.examDate,
    this.examDateString,
    this.numberExpectedStudent,
    this.semesterName,
    this.courseYearName,
    this.registerPeriodName,
    this.examHour,
    this.room,
    this.examCode,
    this.studentCode,
    this.markingCode,
    this.subjectName,
    this.status,
  });
}

class ExamHour {
  final int id;
  final String name;
  final String? code;
  final int start;
  final String startString;
  final int end;
  final String endString;
  final int indexNumber;
  final int type;

  ExamHour({
    required this.id,
    required this.name,
    this.code,
    required this.start,
    required this.startString,
    required this.end,
    required this.endString,
    required this.indexNumber,
    required this.type,
  });
}

class Room {
  final int id;
  final String name;
  final String code;

  Room({required this.id, required this.name, required this.code});
}
