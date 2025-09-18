// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      height: fields[1] as double?,
      weight: fields[2] as double?,
      birthDate: fields[3] as DateTime?,
      gender: fields[4] as String?,
      bodyFatPercentage: fields[5] as double?,
      geminiApiKey: fields[6] as String,
      gptApiKey: fields[7] as String,
      selectedLlm: fields[8] as String,
      dailyKcalGoal: fields[9] as double?,
      dailyProteinGoal: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.height)
      ..writeByte(2)
      ..write(obj.weight)
      ..writeByte(3)
      ..write(obj.birthDate)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.bodyFatPercentage)
      ..writeByte(6)
      ..write(obj.geminiApiKey)
      ..writeByte(7)
      ..write(obj.gptApiKey)
      ..writeByte(8)
      ..write(obj.selectedLlm)
      ..writeByte(9)
      ..write(obj.dailyKcalGoal)
      ..writeByte(10)
      ..write(obj.dailyProteinGoal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
