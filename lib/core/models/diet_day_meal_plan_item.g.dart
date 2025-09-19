// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_day_meal_plan_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietDayMealPlanItemAdapter extends TypeAdapter<DietDayMealPlanItem> {
  @override
  final int typeId = 29;

  @override
  DietDayMealPlanItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietDayMealPlanItem(
      id: fields[0] as String,
      label: fields[1] as String,
      meal: fields[2] as Meal,
      plannedGrams: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DietDayMealPlanItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.meal)
      ..writeByte(3)
      ..write(obj.plannedGrams);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietDayMealPlanItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
