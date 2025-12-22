import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';

class ExamRoomModel extends ExamRoom {
  const ExamRoomModel({
    required super.id,
    required super.subjectName,
    required super.examPeriodCode,
    super.examCode,
    super.studentCode,
    super.examDate,
    super.examTime,
    super.roomName,
    super.roomBuilding,
    super.examMethod,
    super.notes,
    super.numberExpectedStudent,
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
    int? numberExpectedStudent;

    if (json['examRoom'] != null) {
      final roomData = json['examRoom'];

      if (roomData['startHour'] != null &&
          roomData['startHour']['startString'] != null) {
        examTime = roomData['startHour']['startString'];
      } else if (roomData['roomCode'] != null) {
        // Fallback: Try to extract time from roomCode (e.g. CSE406_08-11-2025_10-12_325-A2)
        // Look for pattern like "10-12" or "07:00-09:00"
        final parts = roomData['roomCode'].toString().split('_');
        for (final part in parts) {
          if (RegExp(r'^\d{1,2}[h:]?\d*-\d{1,2}[h:]?\d*$').hasMatch(part)) {
            examTime = part;
            break;
          }
        }
      }

      if (roomData['room'] != null) {
        roomName = roomData['room']['name'];
        roomBuilding = roomData['room']['building'] != null
            ? roomData['room']['building']['name']
            : null;
      }

      examMethod = roomData['examMethod']?['name'];
      notes = roomData['notes'];
      numberExpectedStudent = roomData['numberExpectedStudent'];
    }

    return ExamRoomModel(
      id: json['id'] ?? 0,
      subjectName: json['subjectName'] ?? '',
      examPeriodCode: json['examPeriodCode'] ?? '',
      examCode: json['examCode'],
      studentCode: json['studentCode'],
      examDate: examDate,
      examTime: examTime,
      roomName: roomName,
      roomBuilding: roomBuilding,
      examMethod: examMethod,
      notes: notes,
      numberExpectedStudent: numberExpectedStudent,
    );
  }
}
