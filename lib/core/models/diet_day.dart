import 'package:hive/hive.dart';

part 'diet_day.g.dart';

@HiveType(typeId: 23)
class DietDay extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // ex: "Dia padrão" ou "Fim de semana"

  @HiveField(2)
  String description;

  // Estrutura leve; refeições ficam em MealEntry por data. Este modelo ajuda no planner.
  DietDay({
    required this.id,
    required this.name,
    required this.description,
  });
}
