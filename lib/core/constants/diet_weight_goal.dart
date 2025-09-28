// lib/core/constants/diet_weight_goal.dart

class DietWeightGoal {
  static const String lose = 'lose';
  static const String maintain = 'maintain';
  static const String gain = 'gain';

  static const Map<String, String> _labels = {
    lose: 'Perder peso',
    maintain: 'Manter peso',
    gain: 'Ganhar peso',
  };

  static String? normalize(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value.startsWith('perd')) return lose;
    if (value.startsWith('man')) return maintain;
    if (value.startsWith('gan') || value.startsWith('bulk')) return gain;
    if (_labels.keys.contains(value)) return value;
    return null;
  }

  static String? label(String? goal) => goal == null ? null : _labels[goal];

  static double calorieBias(String? goal) {
    switch (goal) {
      case lose:
        return 1.10; // +10%
      case gain:
        return 0.90; // -10%
      case maintain:
      default:
        return 1.0;
    }
  }
}
