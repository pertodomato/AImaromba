// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_set_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSetEntryAdapter extends TypeAdapter<WorkoutSetEntry> {
  @override
  final int typeId = 25;

  @override
  WorkoutSetEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSetEntry(
      id: fields[0] as String,
      sessionLogId: fields[1] as String,
      exerciseId: fields[2] as String,
      setIndex: fields[3] as int,
      metrics: (fields[4] as Map).cast<String, double>(),
      timestamp: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSetEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionLogId)
      ..writeByte(2)
      ..write(obj.exerciseId)
      ..writeByte(3)
      ..write(obj.setIndex)
      ..writeByte(4)
      ..write(obj.metrics)
      ..writeByte(5)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSetEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
