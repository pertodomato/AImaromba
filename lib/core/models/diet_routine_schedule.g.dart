// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_routine_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietRoutineScheduleAdapter extends TypeAdapter<DietRoutineSchedule> {
  @override
  final int typeId = 44;

  @override
  DietRoutineSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietRoutineSchedule(
      routineSlug: fields[0] as String,
      blockSequence: (fields[1] as List).cast<String>(),
      repetitionSchema: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DietRoutineSchedule obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.routineSlug)
      ..writeByte(1)
      ..write(obj.blockSequence)
      ..writeByte(2)
      ..write(obj.repetitionSchema);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietRoutineScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
