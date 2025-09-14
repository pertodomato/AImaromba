// lib/presentation/providers/dashboard_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitapp/domain/entities/nutrition.dart';
import 'package:fitapp/presentation/providers/repository_providers.dart';
import 'package:fitapp/data/repositories/profile_repository.dart';

class DashboardSummary {
  final DailyNutrition nutrition;
  final bool hasActiveWorkout;
  
  DashboardSummary({required this.nutrition, required this.hasActiveWorkout});
  
  double get kcalProgress {
    if (nutrition.targetKcal == 0) return 0;
    return (nutrition.consumedKcal / nutrition.targetKcal).clamp(0.0, 1.0);
  }
}

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final profile = await ref.watch(profileRepositoryProvider).getActive();
  
  // Usamos .future para obter o primeiro valor dos streams
  final nutrition = await ref.watch(nutritionRepositoryProvider).today(profile.id).first;
  final hasActiveWorkout = await ref.watch(workoutRepositoryProvider).hasActiveWorkout(profile.id).first;

  return DashboardSummary(nutrition: nutrition, hasActiveWorkout: hasActiveWorkout);
});