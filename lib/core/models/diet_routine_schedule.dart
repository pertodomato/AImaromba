// lib/core/models/diet_routine_schedule.dart
import 'package:hive/hive.dart';

part 'diet_routine_schedule.g.dart';

/// Agenda da rotina de DIETA (sequência de blocks).
///
/// Mantém apenas metadados e a **ordem dos blocks** (por slug).
/// A repetição (ex.: "Semanal", "Quinzenal", "Mensal") é armazenada aqui
/// para que a tela/serviço consiga projetar o calendário sem precisar
/// carregar todos os dias.
@HiveType(typeId: 44) // garanta que não conflita com outros adapters
class DietRoutineSchedule extends HiveObject {
  /// Slug da rotina (ex.: `cutting_basico`).
  @HiveField(0)
  String routineSlug;

  /// Sequência ORDENADA de slugs de `DietBlock` (ex.: ["semana_a", "semana_b"]).
  @HiveField(1)
  List<String> blockSequence;

  /// "Semanal" | "Quinzenal" | "Mensal" (ou outro termo padronizado no app).
  @HiveField(2)
  String repetitionSchema;

  DietRoutineSchedule({
    required this.routineSlug,
    required this.blockSequence,
    required this.repetitionSchema,
  });

  // ---- Utilidades (opcionais) ----

  factory DietRoutineSchedule.fromJson(Map<String, dynamic> json) {
    return DietRoutineSchedule(
      routineSlug: (json['routine_slug'] ?? '').toString(),
      blockSequence: List<String>.from(json['block_sequence'] ?? const []),
      repetitionSchema: (json['repetition_schema'] ?? 'Semanal').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'routine_slug': routineSlug,
        'block_sequence': blockSequence,
        'repetition_schema': repetitionSchema,
      };
}
