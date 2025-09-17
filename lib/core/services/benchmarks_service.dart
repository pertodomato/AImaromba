import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:collection/collection.dart';
import 'package:seu_app/core/models/user_profile.dart';
import 'package:seu_app/core/models/exercise.dart';
import 'package:seu_app/core/models/workout_set_entry.dart';
import 'package:seu_app/core/utils/performance_math.dart';

class BenchmarksResult {
  BenchmarksResult({required this.classIndex, required this.value, required this.percentile});
  final int classIndex;    // índice da classe de peso corporal usada
  final double value;      // valor do usuário (kg 1RM ou reps)
  final double percentile; // 0..1
}

class BenchmarksService {
  Map<String, dynamic>? _data;

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/benchmarks.json');
    _data = jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Calcula percentis por benchmarkId usando melhor desempenho do usuário.
  /// Mapas suportados: supino_masculino, agachamento_masculino, terra_masculino, barra_fixa_masculino
  Map<String, BenchmarksResult> computeUserBenchmarks(
    UserProfile profile,
    List<Exercise> exercises,
    List<WorkoutSetEntry> sets,
  ) {
    if (_data == null) return {};

    // mapeia exercícios -> benchmarkId
    String? benchForExercise(Exercise e) {
      final n = e.name.toLowerCase();
      if (n.contains('supino')) return 'supino_masculino';
      if (n.contains('agachamento')) return 'agachamento_masculino';
      if (n.contains('terra')) return 'terra_masculino';
      if (n.contains('barra fixa')) return 'barra_fixa_masculino';
      return null;
    }

    final byExId = {for (final e in exercises) e.id: e};
    final byBench = <String, List<WorkoutSetEntry>>{};
    for (final s in sets) {
      final ex = byExId[s.exerciseId];
      if (ex == null) continue;
      final bid = benchForExercise(ex);
      if (bid == null) continue;
      (byBench[bid] ??= []).add(s);
    }

    final results = <String, BenchmarksResult>{};
    final bodyWeight = (profile.weight ?? 75).toDouble();

    for (final entry in byBench.entries) {
      final id = entry.key;
      final b = _data![id] as Map<String, dynamic>;
      final classes = (b['weights'] as List).map((e) => (e as num).toDouble()).toList();
      final klass = _closestIndex(classes, bodyWeight);

      double userValue = 0;
      if (id == 'barra_fixa_masculino') {
        // usar melhor reps
        for (final s in entry.value) {
          final r = s.metrics['Repetições'] ?? 0;
          if (r > userValue) userValue = r;
        }
      } else {
        // estimar melhor 1RM
        double best = 0;
        for (final s in entry.value) {
          final w = s.metrics['Peso'] ?? 0;
          final r = s.metrics['Repetições'] ?? 0;
          final est = PerformanceMath.epley1RM(w, r);
          if (est > best) best = est;
        }
        userValue = best;
      }

      final percentile = _estimatePercentile(b, klass, userValue);
      results[id] = BenchmarksResult(classIndex: klass, value: userValue, percentile: percentile);
    }

    return results;
  }

  int _closestIndex(List<double> arr, double x) {
    int idx = 0;
    double bestDiff = double.infinity;
    for (var i = 0; i < arr.length; i++) {
      final d = (arr[i] - x).abs();
      if (d < bestDiff) {
        bestDiff = d;
        idx = i;
      }
    }
    return idx;
  }

  /// Retorna percentil 0..1, interpolando entre p10,p25,p50,p75,p90.
  double _estimatePercentile(Map<String, dynamic> bench, int klass, double userVal) {
    final p = bench['percentiles'] as Map<String, dynamic>;
    final p10 = (p['p10'] as List)[klass].toDouble();
    final p25 = (p['p25'] as List)[klass].toDouble();
    final p50 = (p['p50'] as List)[klass].toDouble();
    final p75 = (p['p75'] as List)[klass].toDouble();
    final p90 = (p['p90'] as List)[klass].toDouble();

    if (userVal <= p10) return 0.10 * (userVal / (p10 == 0 ? 1 : p10));
    if (userVal <= p25) return _lin(userVal, p10, p25, 0.10, 0.25);
    if (userVal <= p50) return _lin(userVal, p25, p50, 0.25, 0.50);
    if (userVal <= p75) return _lin(userVal, p50, p75, 0.50, 0.75);
    if (userVal <= p90) return _lin(userVal, p75, p90, 0.75, 0.90);
    // acima de p90 extrapola levemente até 0.99
    return 0.90 + 0.09 * ((userVal - p90) / (p90 == 0 ? 1 : p90)).clamp(0, 1);
  }

  double _lin(double v, double a, double b, double pa, double pb) {
    if (b == a) return pa;
    final t = ((v - a) / (b - a)).clamp(0, 1);
    return pa + (pb - pa) * t;
  }
}
