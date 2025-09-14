// lib/presentation/providers/repository_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/implementations/profile_repository_impl.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/scan_repository.dart';
import 'database_provider.dart';

// --- PROVIDERS CONCRETOS ---

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProfileRepositoryImpl(db);
});

// Providers restantes ainda usarão stubs para não quebrar a compilação
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  // final db = ref.watch(databaseProvider);
  // return WorkoutRepositoryImpl(db);
  throw UnimplementedError("WorkoutRepositoryImpl not created yet");
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  // final db = ref.watch(databaseProvider);
  // return NutritionRepositoryImpl(db);
  throw UnimplementedError("NutritionRepositoryImpl not created yet");
});

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  // return ScanRepositoryImpl();
  throw UnimplementedError("ScanRepositoryImpl not created yet");
});