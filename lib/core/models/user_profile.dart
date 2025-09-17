import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double? height; // em cm

  @HiveField(2)
  double? weight; // em kg

  @HiveField(3)
  DateTime? birthDate;

  @HiveField(4)
  String? gender; // "Male", "Female", "Other"

  @HiveField(5)
  double? bodyFatPercentage;
  
  @HiveField(6)
  String geminiApiKey;
  
  @HiveField(7)
  String gptApiKey;

  @HiveField(8)
  String selectedLlm; // "gemini", "gpt"

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
  });
}