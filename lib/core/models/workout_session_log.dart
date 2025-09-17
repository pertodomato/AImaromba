import 'package:hive/hive.dart';

part 'workout_session_log.g.dart';

@HiveType(typeId: 26)
class WorkoutSessionLog extends HiveObject {
  @HiveField(0)
  String id; // uuid

  @HiveField(1)
  String workoutSessionId; // WorkoutSession.id (modelo-base)

  @HiveField(2)
  DateTime startedAt;

  @HiveField(3)
  DateTime? endedAt;

  @HiveField(4)
  String? note;

  WorkoutSessionLog({
    required this.id,
    required this.workoutSessionId,
    required this.startedAt,
    this.endedAt,
    this.note,
  });
}
