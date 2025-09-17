import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Estrutura mínima para usar assets/benchmarks.json
class BenchmarksService {
  late final Map<String, dynamic> _db;

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/benchmarks.json');
    _db = jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Retorna percentil aproximado [0..1] para um lift dado BW e 1RM estimado.
  /// Lifts suportados: supino_masculino, agachamento_masculino, terra_masculino, barra_fixa_masculino
  double? percentile(String liftKey, double bodyWeightKg, double value) {
    final lift = _db[liftKey];
    if (lift == null) return null;
    final weights = List<num>.from(lift['weights']).map((e) => e.toDouble()).toList();
    final idx = _closestIndex(weights, bodyWeightKg);
    final p = lift['percentiles'] as Map<String, dynamic>;
    final p10 = (p['p10'][idx] as num).toDouble();
    final p25 = (p['p25'][idx] as num).toDouble();
    final p50 = (p['p50'][idx] as num).toDouble();
    final p75 = (p['p75'][idx] as num).toDouble();
    final p90 = (p['p90'][idx] as num).toDouble();

    // interpola faixas
    if (value <= p10) return 0.10;
    if (value >= p90) return 0.90;
    if (value <= p25) return 0.10 + (value - p10) / (p25 - p10) * 0.15;
    if (value <= p50) return 0.25 + (value - p25) / (p50 - p25) * 0.25;
    if (value <= p75) return 0.50 + (value - p50) / (p75 - p50) * 0.25;
    return 0.75 + (value - p75) / (p90 - p75) * 0.15;
  }

  int _closestIndex(List<double> arr, double x) {
    int best = 0;
    double bestDiff = (arr[0] - x).abs();
    for (int i = 1; i < arr.length; i++) {
      final d = (arr[i] - x).abs();
      if (d < bestDiff) { best = i; bestDiff = d; }
    }
    return best;
  }

  /// Heurística simples por nome do exercício.
  String? mapExerciseToLift(String nameLower) {
    if (nameLower.contains('supino')) return 'supino_masculino';
    if (nameLower.contains('agachamento')) return 'agachamento_masculino';
    if (nameLower.contains('levantamento terra') || nameLower.contains('terra')) return 'terra_masculino';
    if (nameLower.contains('barra fixa')) return 'barra_fixa_masculino';
    return null;
  }
}
