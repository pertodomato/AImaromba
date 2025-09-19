// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_block.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DietBlockAdapter extends TypeAdapter<DietBlock> {
  @override
  final int typeId = 42;

  @override
  DietBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietBlock(
      slug: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      daySlugs: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DietBlock obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.slug)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.daySlugs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietBlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
