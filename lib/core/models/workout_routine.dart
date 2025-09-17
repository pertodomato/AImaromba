import 'package:hive/hive.dart';
import 'package:seu_app/core/models/workout_day.dart';

part 'workout_routine.g.dart';

@HiveType(typeId: 10) // Use um typeId não utilizado
class WorkoutRoutine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  String repetitionSchema; // "Semanal", "Quinzenal", etc.

  @HiveField(5)
  HiveList<WorkoutDay> days; // Lista de dias de treino na rotina

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.repetitionSchema,
    required this.days,
  });
}