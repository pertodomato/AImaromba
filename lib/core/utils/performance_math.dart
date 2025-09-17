double epley1RM(double peso, int reps) => reps <= 1 ? peso : peso * (1 + reps / 30.0);
double brzycki1RM(double peso, int reps) => reps <= 1 ? peso : peso * 36.0 / (37.0 - reps);

/// Lê métricas PT-BR padrão: "Peso", "Repetições"
double? best1RMFromMetrics(Map<String, String> metrics) {
  final w = double.tryParse(metrics['Peso'] ?? '');
  final r = int.tryParse(metrics['Repetições'] ?? '');
  if (w == null || r == null || r <= 0) return null;
  final e = epley1RM(w, r);
  final b = brzycki1RM(w, r);
  return (e + b) / 2.0;
}
class PerformanceMath {
  /// Epley: 1RM = w * (1 + r/30)
  static double epley1RM(double weightKg, double reps) {
    if (weightKg <= 0 || reps <= 0) return 0;
    return weightKg * (1 + reps / 30.0);
  }

  /// Brzycki: 1RM = w * 36 / (37 - r)
  static double brzycki1RM(double weightKg, double reps) {
    if (weightKg <= 0 || reps <= 0 || reps >= 37) return 0;
    return weightKg * 36.0 / (37.0 - reps);
  }
}
