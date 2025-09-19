// lib/core/models/workout_block.dart
import 'package:hive/hive.dart';

part 'workout_block.g.dart';

@HiveType(typeId: 41) // escolha um ID livre no seu app
class WorkoutBlock extends HiveObject {
  @HiveField(0)
  String slug; // ex.: "ppl_semana_padrao"

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  /// Lista ORDENADA de slugs de WorkoutDay que compõem este block (1–15 itens).
  @HiveField(3)
  List<String> daySlugs;

  WorkoutBlock({
    required this.slug,
    required this.name,
    required this.description,
    required this.daySlugs,
  });
}
