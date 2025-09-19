// lib/core/models/routine_schedule.dart
import 'package:hive/hive.dart';

part 'routine_schedule.g.dart';

/// Schedule genérico para rotinas de treino ou dieta.
/// type: "workout" | "diet"
@HiveType(typeId: 53)
class RoutineSchedule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type;

  @HiveField(2)
  String routineId;

  /// Ordem dos blocks a repetir (ex.: ["semana","semana","fim_semana"])
  @HiveField(3)
  List<String> blockIds;

  /// "Semanal" | "Quinzenal" | "Mensal"
  @HiveField(4)
  String repetitionSchema;

  RoutineSchedule({
    required this.id,
    required this.type,
    required this.routineId,
    required this.blockIds,
    required this.repetitionSchema,
  });
}
