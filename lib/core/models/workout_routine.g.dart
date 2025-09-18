// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_routine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutRoutineAdapter extends TypeAdapter<WorkoutRoutine> {
  @override
  final int typeId = 10;

  @override
  WorkoutRoutine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutRoutine(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      startDate: fields[3] as DateTime,
      repetitionSchema: fields[4] as String,
      days: (fields[5] as HiveList).castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutRoutine obj) {
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
      other is WorkoutRoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
