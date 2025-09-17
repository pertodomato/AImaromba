import 'package:hive/hive.dart';
import 'exercise.dart';

part 'workout_session.g.dart';

@HiveType(typeId: 11)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  HiveList<Exercise> exercises;

  WorkoutSession({
    required this.id,
    required this.name,
    required this.description,
    required this.exercises,
  });
}
