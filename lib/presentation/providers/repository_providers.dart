// lib/presentation/providers/repository_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/implementations/profile_repository_impl.dart';
import '../../data/repositories/implementations/workout_repository_impl.dart';
import '../../data/repositories/implementations/nutrition_repository_impl.dart';
import '../../data/repositories/implementations/scan_repository_impl.dart';

import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/scan_repository.dart';

import 'database_provider.dart'; // fornece AppDatabase (Drift)

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProfileRepositoryImpl(db.sqlite); // se AppDatabase expõe `sqlite` (DatabaseConnectionUser)
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WorkoutRepositoryImpl(db);
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return NutritionRepositoryImpl(db);
});

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  return ScanRepositoryImpl();
});
