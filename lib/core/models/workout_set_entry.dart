import 'package:hive/hive.dart';

part 'workout_set_entry.g.dart';

@HiveType(typeId: 25)
class WorkoutSetEntry extends HiveObject {
  @HiveField(0)
  String id; // uuid

  @HiveField(1)
  String sessionLogId; // FK para WorkoutSessionLog.id

  @HiveField(2)
  String exerciseId; // Exercise.id

  @HiveField(3)
  int setIndex; // 1..N

  /// Valores genéricos por métrica. Use chaves padronizadas ["Peso","Repetições","Séries","Distância","Tempo","DescansoSeg"]
  @HiveField(4)
  Map<String, double> metrics;

  @HiveField(5)
  DateTime timestamp;

  WorkoutSetEntry({
    required this.id,
    required this.sessionLogId,
    required this.exerciseId,
    required this.setIndex,
    required this.metrics,
    required this.timestamp,
  });
}
