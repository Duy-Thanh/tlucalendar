import 'package:equatable/equatable.dart';

class SemesterRegisterPeriod extends Equatable {
  final int id;
  final String name;
  final int startRegisterTime;
  final int endRegisterTime;
  final int endUnRegisterTime;

  const SemesterRegisterPeriod({
    required this.id,
    required this.name,
    required this.startRegisterTime,
    required this.endRegisterTime,
    required this.endUnRegisterTime,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    startRegisterTime,
    endRegisterTime,
    endUnRegisterTime,
  ];
}
