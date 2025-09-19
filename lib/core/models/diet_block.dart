// lib/core/models/diet_block.dart
import 'package:hive/hive.dart';

part 'diet_block.g.dart';

@HiveType(typeId: 42) // escolha um ID livre no seu app
class DietBlock extends HiveObject {
  @HiveField(0)
  String slug; // ex.: "semana_com_refeicao_livre"

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  /// Lista ORDENADA de slugs de DietDay que compõem este block (1–15 itens).
  @HiveField(3)
  List<String> daySlugs;

  DietBlock({
    required this.slug,
    required this.name,
    required this.description,
    required this.daySlugs,
  });
}
