// lib/core/utils/nutrition_math.dart
import 'dart:math';
import 'package:seu_app/core/models/user_profile.dart';

class NutritionTargets {
  final double kcalTarget;
  final double proteinTargetG;
  const NutritionTargets({required this.kcalTarget, required this.proteinTargetG});
}

class NutritionMath {
  /// Estima BMR usando Katch-McArdle se %gordura presente, senão Mifflin-St Jeor.
  static double estimateBmr(UserProfile p) {
    final w = (p.weight ?? 75).toDouble();
    final h = (p.height ?? 175).toDouble();
    final age = _yearsFrom(p.birthDate) ?? 30;
    final bf = p.bodyFatPercentage;

    if (bf != null && bf > 0 && bf < 60) {
      final leanMass = w * (1 - bf / 100.0);
      return 370.0 + 21.6 * leanMass; // Katch-McArdle
    }

    final sexAdj = (p.gender == 'Female') ? -161.0 : 5.0;
    return 10.0 * w + 6.25 * h - 5.0 * age + sexAdj; // Mifflin
  }

  /// Fator de atividade heurístico a partir de respostas. Default moderado 1.5.
  static double inferActivityFactor(Map<String, String> answers) {
    final blob = answers.values.map((s) => s.toLowerCase()).join(' ');
    if (_hasAny(blob, ['sedent', 'parado', 'baixa'])) return 1.3;
    if (_hasAny(blob, ['leve', 'light'])) return 1.4;
    if (_hasAny(blob, ['moderad'])) return 1.55;
    if (_hasAny(blob, ['alto', 'intens', 'pesado'])) return 1.75;
    return 1.5;
  }

  /// Ajuste por objetivo. Deficit -15%, superavit +10% por padrão.
  static double goalMultiplier({required String goalText, required Map<String, String> answers}) {
    final t = (goalText + ' ' + answers.values.join(' ')).toLowerCase();
    if (_hasAny(t, ['perder', 'cut', 'déficit', 'deficit', 'secar'])) return 0.85;
    if (_hasAny(t, ['ganhar', 'bulk', 'superavit', 'superávit', 'massa'])) return 1.10;
    if (_hasAny(t, ['manter', 'maintenance', 'manutenção'])) return 1.00;
    return 1.00;
  }

  /// Proteína alvo g/dia. 1.6–2.2 g/kg → usa 1.8 g/kg por padrão.
  static double proteinTarget(UserProfile p) {
    final w = (p.weight ?? 70).toDouble();
    return (1.8 * w).clamp(90.0, 220.0);
  }

  static NutritionTargets estimateDailyTargets({
    required UserProfile profile,
    required String goalText,
    required Map<String, String> answers,
  }) {
    final bmr = estimateBmr(profile);
    final act = inferActivityFactor(answers);
    final goal = goalMultiplier(goalText: goalText, answers: answers);
    final tdee = bmr * act;
    final kcal = _roundTo10(tdee * goal);
    final prot = _roundTo5(proteinTarget(profile));
    return NutritionTargets(kcalTarget: kcal, proteinTargetG: prot);
  }

  static int? _yearsFrom(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    var years = now.year - d.year;
    final hadBirthday = (now.month > d.month) || (now.month == d.month && now.day >= d.day);
    if (!hadBirthday) years -= 1;
    return max(0, years);
  }

  static bool _hasAny(String t, List<String> keys) => keys.any((k) => t.contains(k));
  static double _roundTo10(double x) => (x / 10.0).round() * 10.0;
  static double _roundTo5(double x) => (x / 5.0).round() * 5.0;
}
