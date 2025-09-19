// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_day_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietDayPlanAdapter extends TypeAdapter<DietDayPlan> {
  @override
  final int typeId = 28;

  @override
  DietDayPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietDayPlan(
      id: fields[0] as String,
      dietDayId: fields[1] as String,
      items: (fields[2] as HiveList).castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, DietDayPlan obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dietDayId)
      ..writeByte(2)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietDayPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
