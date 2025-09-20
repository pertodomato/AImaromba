// lib/core/models/diet_routine_schedule.dart
import 'package:hive/hive.dart';

part 'diet_routine_schedule.g.dart';

/// Agenda da rotina de DIETA (sequência de blocks)
@HiveType(typeId: 44) // escolha um ID livre e mantenha consistente
class DietRoutineSchedule extends HiveObject {
  @HiveField(0)
  String routineSlug; // slug da DietRoutine

  @HiveField(1)
  List<String> blockSequence; // lista de slugs dos DietBlock na ordem

  @HiveField(2)
  String repetitionSchema; // "Semanal" | "Quinzenal" | "Mensal"

  DietRoutineSchedule({
    required this.routineSlug,
    required this.blockSequence,
    required this.repetitionSchema,
  });
}
