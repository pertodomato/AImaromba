import 'package:hive/hive.dart';
import 'workout_session.dart';

part 'workout_day.g.dart';

@HiveType(typeId: 12)
class WorkoutDay extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  HiveList<WorkoutSession> sessions;

  WorkoutDay({
    required this.id,
    required this.name,
    required this.description,
    required this.sessions,
  });
}
