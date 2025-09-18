// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_day.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietDayAdapter extends TypeAdapter<DietDay> {
  @override
  final int typeId = 23;

  @override
  DietDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietDay(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DietDay obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
