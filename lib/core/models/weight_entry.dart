import 'package:hive/hive.dart';

part 'weight_entry.g.dart';

@HiveType(typeId: 22)
class WeightEntry extends HiveObject {
  @HiveField(0)
  String id; // uuid

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  double weightKg;

  WeightEntry({
    required this.id,
    required this.dateTime,
    required this.weightKg,
  });
}
