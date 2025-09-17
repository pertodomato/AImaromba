import 'package:muscle_selector/muscle_selector.dart';

bool isValidMuscleName(String name) {
  for (final m in Muscle.values) {
    if (m.name == name) return true;
  }
  return false;
}
