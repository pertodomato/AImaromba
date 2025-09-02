import 'dart:math';
import 'package:hive/hive.dart';

// 1RM: Brzycki (<=10 reps) e Epley (>10 reps)
double estimate1RM(double weight, int reps) {
  if (reps <= 0) return 0;
  if (reps <= 10) {
    return weight / (1.0278 - 0.0278 * reps);
  } else {
    return weight * (1 + reps / 30.0);
  }
}

// Interpolação por peso corporal entre bins (percentis em benchmarks.json)
double percentileFor({
  required String exerciseKey, // 'supino' | 'agachamento' | 'terra' | 'barra_fixa'
  required String genderKey,  // 'masculino' | 'feminino'
  required double bodyWeight,
  required double value,      // 1RM (ou reps no caso da barra fixa)
}) {
  final bench = Hive.box('benchmarks').get('data');
  final table = bench['${exerciseKey}_${genderKey}'];
  if (table == null) return 0;
  final List weights = table['weights'];
  final Map<String, dynamic> percMap = Map<String, dynamic>.from(table['percentiles']);

  // encontrar wLo/wHi
  double wLo = (weights.first as num).toDouble();
  double wHi = (weights.last as num).toDouble();
  for (int i = 0; i < weights.length; i++) {
    final w = (weights[i] as num).toDouble();
    if (w <= bodyWeight) wLo = w;
    if (w >= bodyWeight) { wHi = w; break; }
  }
  int idxLo = weights.indexOf(wLo);
  int idxHi = weights.indexOf(wHi);
  if (idxLo < 0) idxLo = 0; if (idxHi < 0) idxHi = weights.length - 1;

  // gera mapa percentil->valorInterpolado
  final percentKeys = ['p10','p25','p50','p75','p90'];
  final interp = <double,double>{};
  for (final k in percentKeys) {
    final List vals = percMap[k];
    final vLo = (vals[idxLo] as num).toDouble();
    final vHi = (vals[idxHi] as num).toDouble();
    double v = vLo;
    if (wHi != wLo) {
      v = vLo + (bodyWeight - wLo) / (wHi - wLo) * (vHi - vLo);
    }
    final pNum = double.parse(k.substring(1)); // 'p50' -> 50
    interp[pNum] = v;
  }

  // acha intervalo de percentil por valor
  final ordered = interp.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
  double prevP = ordered.first.key;
  double prevV = ordered.first.value;
  for (int i=1;i<ordered.length;i++){
    final p = ordered[i].key; final v = ordered[i].value;
    if (value <= v) {
      final frac = (value - prevV) / max(1e-9, (v - prevV));
      return (prevP + frac * (p - prevP)).clamp(0, 100);
    }
    prevP = p; prevV = v;
  }
  return 100; // acima do p90
}

// Calorias (cardio/força) via MET ~ kcal = MET * peso(kg) * horas
double kcalFromMET({required double met, required double bodyWeightKg, required double minutes}) {
  return met * bodyWeightKg * (minutes / 60.0);
}
// Lista canônica de boxes usadas no app
const kBoxes = <String>[
  'settings','profile','exercises','benchmarks','foods',
  'blocks','routine','sessions','foodlogs'
];