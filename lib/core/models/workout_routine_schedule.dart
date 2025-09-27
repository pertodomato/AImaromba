// lib/core/models/workout_routine_schedule.dart
import 'package:hive/hive.dart';

part 'workout_routine_schedule.g.dart';

@HiveType(typeId: 43) // escolha um ID livre no seu app
class WorkoutRoutineSchedule extends HiveObject {
  @HiveField(0)
  String routineSlug; // slug do WorkoutRoutine

  /// Sequência ORDENADA de slugs de WorkoutBlock que a rotina repete.
  /// (ex.: ["block_semana", "block_semana", ...] ou ["ciclo_quinzenal"])
  @HiveField(1)
  List<String> blockSequence;

  @HiveField(2)
  String repetitionSchema; // "Semanal" | "Quinzenal" | "Mensal"

  /// Data em que a rotina deve ser encerrada. Quando nulo, a UI assume
  /// um horizonte padrão (ex.: 6 meses a partir do início).
  @HiveField(3)
  DateTime? endDate;

  WorkoutRoutineSchedule({
    required this.routineSlug,
    required this.blockSequence,
    required this.repetitionSchema,
    this.endDate,
  });
}
