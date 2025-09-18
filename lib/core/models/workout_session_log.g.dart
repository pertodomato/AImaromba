// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSessionLogAdapter extends TypeAdapter<WorkoutSessionLog> {
  @override
  final int typeId = 26;

  @override
  WorkoutSessionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSessionLog(
      id: fields[0] as String,
      workoutSessionId: fields[1] as String,
      startedAt: fields[2] as DateTime,
      endedAt: fields[3] as DateTime?,
      note: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSessionLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workoutSessionId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.endedAt)
      ..writeByte(4)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
