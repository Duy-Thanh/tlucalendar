import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';

class ExamRoomModel extends ExamRoom {
  const ExamRoomModel({
    required super.id,
    required super.subjectName,
    required super.examPeriodCode,
    super.studentCode,
    super.examDate,
    super.examTime,
    super.roomName,
    super.roomBuilding,
    super.examMethod,
    super.notes,
  });

  factory ExamRoomModel.fromJson(Map<String, dynamic> json) {
    DateTime? examDate;
    if (json['examRoom'] != null && json['examRoom']['examDate'] != null) {
      examDate = DateTime.fromMillisecondsSinceEpoch(
        json['examRoom']['examDate'],
      );
    }

    String? examTime;
    String? roomName;
    String? roomBuilding;
    String? examMethod;
    String? notes;

    if (json['examRoom'] != null) {
      final roomData = json['examRoom'];

      if (roomData['startHour'] != null &&
          roomData['startHour']['startString'] != null) {
        examTime = roomData['startHour']['startString'];
      }

      if (roomData['room'] != null) {
        roomName = roomData['room']['name'];
        roomBuilding = roomData['room']['building'];
      }

      examMethod = roomData['examMethod']?['name'];
      notes = roomData['notes'];
    }

    return ExamRoomModel(
      id: json['id'] ?? 0,
      subjectName: json['subjectName'] ?? '',
      examPeriodCode: json['examPeriodCode'] ?? '',
      studentCode: json['studentCode'],
      examDate: examDate,
      examTime: examTime,
      roomName: roomName,
      roomBuilding: roomBuilding,
      examMethod: examMethod,
      notes: notes,
    );
  }
}
