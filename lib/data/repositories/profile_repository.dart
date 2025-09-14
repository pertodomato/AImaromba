// lib/data/repositories/profile_repository.dart
import 'dart:ui';

// Futuramente, os modelos virão de 'package:fitapp/data/models/...'
class Profile {
  final int id;
  final String name;
  final Locale locale;
  Profile({required this.id, required this.name, required this.locale});
}

abstract interface class ProfileRepository {
  Future<Profile> getActive();
  Future<void> setLocale(String localeCode);
  Future<void> saveProfile(Profile profile);
  Future<bool> isFirstRun();
  Future<void> seedInitialData(); // Para substituir _firstRunLoad
}