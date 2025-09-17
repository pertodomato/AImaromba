import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double? height; // cm

  @HiveField(2)
  double? weight; // kg

  @HiveField(3)
  DateTime? birthDate;

  @HiveField(4)
  String? gender;

  @HiveField(5)
  double? bodyFatPercentage;

  @HiveField(6)
  String geminiApiKey;

  @HiveField(7)
  String gptApiKey;

  @HiveField(8)
  String selectedLlm; // "gemini", "gpt"

  @HiveField(9)
  double? dailyKcalGoal;

  @HiveField(10)
  double? dailyProteinGoal;

  UserProfile({
    this.name = '',
    this.height,
    this.weight,
    this.birthDate,
    this.gender,
    this.bodyFatPercentage,
    this.geminiApiKey = '',
    this.gptApiKey = '',
    this.selectedLlm = 'gemini',
    this.dailyKcalGoal,
    this.dailyProteinGoal,
  });
}
