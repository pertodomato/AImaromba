import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final profileProvider = Provider<Map>((ref) => Hive.box('profile').toMap());

class CalorieStatus {
  final double target, consumed, burned, balance;
  CalorieStatus(this.target, this.consumed, this.burned)
      : balance = target - (consumed - burned);
}

final calorieStatusProvider = Provider<CalorieStatus>((ref) {
  final profile = Hive.box('profile');
  final target = (profile.get('calorieTarget', defaultValue: 2000) as num).toDouble();
  final today = DateTime.now().toIso8601String().substring(0,10);

  final foodlogs = Hive.box('foodlogs');
  double consumed = 0;
  for (final e in foodlogs.values) {
    if (e['date'] == today) consumed += (e['kcal'] as num).toDouble();
  }

  final sessions = Hive.box('sessions');
  double burned = 0;
  for (final s in sessions.values) {
    if (s['date'] == today) burned += ((s['calories'] ?? 0) as num).toDouble();
  }
  return CalorieStatus(target, consumed, burned);
});

final xpProvider = Provider<int>((ref) => Hive.box('profile').get('xp', defaultValue: 0));

final neglectedMusclesProvider = Provider<List<String>>((ref) {
  final Map<String, dynamic> m = Map.from(Hive.box('profile').get('muscleVolumeScore', defaultValue: <String,double>{}));
  final entries = m.entries.where((e) => (e.value as num).toDouble() < 3).map((e)=> e.key).toList();
  return entries;
});
