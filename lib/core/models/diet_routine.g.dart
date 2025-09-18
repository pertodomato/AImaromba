// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_routine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietRoutineAdapter extends TypeAdapter<DietRoutine> {
  @override
  final int typeId = 24;

  @override
  DietRoutine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietRoutine(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      startDate: fields[3] as DateTime,
      repetitionSchema: fields[4] as String,
      days: (fields[5] as HiveList).castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, DietRoutine obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.repetitionSchema)
      ..writeByte(5)
      ..write(obj.days);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietRoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
