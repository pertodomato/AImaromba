// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_routine_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutRoutineScheduleAdapter
    extends TypeAdapter<WorkoutRoutineSchedule> {
  @override
  final int typeId = 43;

  @override
  WorkoutRoutineSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutRoutineSchedule(
      routineSlug: fields[0] as String,
      blockSequence: (fields[1] as List).cast<String>(),
      repetitionSchema: fields[2] as String,
      endDate: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutRoutineSchedule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.routineSlug)
      ..writeByte(1)
      ..write(obj.blockSequence)
      ..writeByte(2)
      ..write(obj.repetitionSchema)
      ..writeByte(3)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutRoutineScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
