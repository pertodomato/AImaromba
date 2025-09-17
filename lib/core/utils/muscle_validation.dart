import 'package:muscle_selector/muscle_selector.dart';

/// Conjunto canônico de nomes válidos de músculos (exatos, conforme enum Muscle).
final Set<String> kAllowedMuscles =
    Muscle.values.map((m) => m.name).toSet(growable: false);

/// Verdadeiro se o nome está exatamente em kAllowedMuscles.
bool isValidMuscleName(String name) => kAllowedMuscles.contains(name);

/// Filtra uma lista mantendo apenas nomes válidos do enum Muscle.
List<String> filterValidMuscles(Iterable<String> names) {
  return names.where(isValidMuscleName).toSet().toList(); // sem duplicatas
}

/// Filtra pares primários/secundários e garante consistência (sem interseção).
Map<String, List<String>> clampPrimarySecondary({
  required Iterable<String> primary,
  required Iterable<String> secondary,
}) {
  final p = filterValidMuscles(primary);
  final s = filterValidMuscles(secondary).where((m) => !p.contains(m)).toList();
  return {'primary': p, 'secondary': s};
}
