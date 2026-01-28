import 'package:equatable/equatable.dart';

class StudentMark extends Equatable {
  final String subjectCode;
  final String subjectName;
  final int numberOfCredit;
  final double mark; // tongkethocphan
  final double markQT; // diemquatrinh
  final double markTHI; // diemthi
  final String charMark; // diemchu
  final int studyTime; // lanhoc
  final int examRound; // lanthi
  final bool isCalculateMark; // tinhdiem
  final String semesterCode;
  final String semesterName;
  final int semesterId;

  const StudentMark({
    required this.subjectCode,
    required this.subjectName,
    required this.numberOfCredit,
    required this.mark,
    required this.markQT,
    required this.markTHI,
    required this.charMark,
    required this.studyTime,
    required this.examRound,
    required this.isCalculateMark,
    required this.semesterCode,
    required this.semesterName,
    required this.semesterId,
  });

  @override
  List<Object?> get props => [
    subjectCode,
    subjectName,
    numberOfCredit,
    mark,
    markQT,
    markTHI,
    charMark,
    studyTime,
    examRound,
    isCalculateMark,
    semesterCode,
    semesterName,
    semesterId,
  ];
}
