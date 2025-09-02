import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../services/util.dart';

final todaysWorkoutProvider = Provider<Map?>((ref) {
  final profile = Hive.box('profile');
  final routineId = profile.get('activeRoutine');
  if (routineId == null) return null;
  final routine = Hive.box('routine').get(routineId);
  if (routine == null) return null;
  final today = DateTime.now().toIso8601String().substring(0,10);
  final blockId = routine['calendar'][today];
  if (blockId == null || blockId == 'descanso') return null;
  return Hive.box('blocks').get(blockId);
});

String levelLabel(double p){
  if (p < 40) return 'Abaixo da média';
  if (p < 60) return 'Na média';
  if (p < 90) return 'Acima da média';
  return 'Elite';
}

Map<String, dynamic> computePercentiles() {
  final profile = Hive.box('profile');
  final gender = (profile.get('gender', defaultValue: 'M') == 'M') ? 'masculino' : 'feminino';
  final bw = (profile.get('weight', defaultValue: 75.0) as num).toDouble();

  double? sup = (profile.get('best1RM_supino') as num?)?.toDouble();
  double? sqt = (profile.get('best1RM_agachamento') as num?)?.toDouble();
  double? dl  = (profile.get('best1RM_terra') as num?)?.toDouble();
  double? puReps = (profile.get('bestReps_barra_fixa') as num?)?.toDouble();

  final res = <String, Map<String, dynamic>>{};
  if (sup != null) {
    final p = percentileFor(exerciseKey: 'supino', genderKey: gender, bodyWeight: bw, value: sup);
    res['Supino'] = {'p': p, 'label': levelLabel(p)};
  }
  if (sqt != null) {
    final p = percentileFor(exerciseKey: 'agachamento', genderKey: gender, bodyWeight: bw, value: sqt);
    res['Agachamento'] = {'p': p, 'label': levelLabel(p)};
  }
  if (dl != null) {
    final p = percentileFor(exerciseKey: 'terra', genderKey: gender, bodyWeight: bw, value: dl);
    res['Terra'] = {'p': p, 'label': levelLabel(p)};
  }
  if (puReps != null) {
    final p = percentileFor(exerciseKey: 'barra_fixa', genderKey: gender, bodyWeight: bw, value: puReps);
    res['Barra Fixa'] = {'p': p, 'label': levelLabel(p)};
  }
  return res;
}
