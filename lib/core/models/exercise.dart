import 'package:hive/hive.dart';

part 'exercise.g.dart';

@HiveType(typeId: 1)
class Exercise extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  List<String> primaryMuscles; // Nomes exatos do muscle_selector

  @HiveField(4)
  List<String> secondaryMuscles;

  @HiveField(5)
  List<String> relevantMetrics; // Ex: ["weight", "reps"], ["distance", "time"]

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.relevantMetrics,
  });
}