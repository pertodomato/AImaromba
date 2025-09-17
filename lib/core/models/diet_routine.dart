import 'package:hive/hive.dart';
import 'diet_day.dart';

part 'diet_routine.g.dart';

@HiveType(typeId: 24)
class DietRoutine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  String repetitionSchema; // "Semanal", "Quinzenal"

  @HiveField(5)
  HiveList<DietDay> days;

  DietRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.repetitionSchema,
    required this.days,
  });
}
