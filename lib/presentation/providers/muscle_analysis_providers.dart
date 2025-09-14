// lib/presentation/providers/muscle_analysis_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitapp/data/repositories/profile_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/presentation/providers/repository_providers.dart';

/// Modelo de dados unificado para a tela de Análise Muscular.
class MuscleAnalysisData {
  /// Buckets para o mapa de calor de recência.
  /// Ex: {'green': {'chest'}, 'yellow': {'legs'}, 'red': {'biceps'}}
  final Map<String, Set<String>> recencyBuckets;

  /// Buckets para o mapa de calor de percentil de força.
  final Map<String, Set<String>> percentileBuckets;

  /// Histórico de treinos formatado para os gráficos.
  final List<WorkoutHistoryEntry> workoutHistory;

  MuscleAnalysisData({
    required this.recencyBuckets,
    required this.percentileBuckets,
    required this.workoutHistory,
  });
}

/// Provider que busca e processa todos os dados para a tela de Análise Muscular.
final muscleAnalysisProvider = FutureProvider<MuscleAnalysisData>((ref) async {
  final profile = await ref.watch(profileRepositoryProvider).getActive();
  final workoutRepo = ref.watch(workoutRepositoryProvider);

  // 1. Buscar dados brutos do repositório
  final history = await workoutRepo.getWorkoutHistory(profile.id);
  final recency = await workoutRepo.getMuscleGroupRecency(profile.id);
  // NOTA: A lógica de percentil seria mais complexa e depende de benchmarks.
  // Por enquanto, usaremos um placeholder para os buckets de percentil.
  
  // 2. Processar dados para a UI
  
  // Lógica para criar buckets de recência
  final Map<String, Set<String>> recencyBuckets = {
    'green': {}, // Treinado > 5 dias atrás (pronto)
    'yellow': {},// Treinado 3-5 dias atrás (recuperando)
    'red': {},   // Treinado 0-2 dias atrás (descansar)
  };
  recency.forEach((muscleGroup, daysSince) {
    if (daysSince <= 2) {
      recencyBuckets['red']!.add(muscleGroup);
    } else if (daysSince <= 5) {
      recencyBuckets['yellow']!.add(muscleGroup);
    } else {
      recencyBuckets['green']!.add(muscleGroup);
    }
  });

  // Lógica placeholder para percentis (a ser substituída por uma consulta real)
  final percentileBuckets = {
      'green': {'triceps', 'lower_back', 'obliques'},
      'yellow': {'traps', 'calves', 'forearm'},
      'red': {'biceps', 'chest', 'abs'},
      'purple': {'quads', 'glutes', 'adductors'}
  };


  return MuscleAnalysisData(
    recencyBuckets: recencyBuckets,
    percentileBuckets: percentileBuckets,
    workoutHistory: history,
  );
});