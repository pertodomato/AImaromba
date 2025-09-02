import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'router.dart';

Future<void> _ensureBoxes() async {
  for (final name in [
    'settings','profile','exercises','benchmarks','foods',
    'blocks','routine','sessions','foodlogs'
  ]) {
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox(name);
    }
  }
}

Future<void> _firstRunLoad() async {
  final settings = Hive.box('settings');
  final firstRun = settings.get('firstRun', defaultValue: true);
  if (!firstRun) return;

  // Importa JSONs de assets (mínimos)
  final exercisesBox = Hive.box('exercises');
  final exStr = await rootBundle.loadString('assets/exercise_db.json');
  final exList = jsonDecode(exStr) as List;
  for (final e in exList) {
    exercisesBox.put(e['id'], e);
  }

  final benchStr = await rootBundle.loadString('assets/benchmarks.json');
  Hive.box('benchmarks').put('data', jsonDecode(benchStr));

  final foodStr = await rootBundle.loadString('assets/taco.json');
  Hive.box('foods').put('items', jsonDecode(foodStr));

  // Perfil default
  final profile = Hive.box('profile');
  profile.putAll({
    'gender': 'M',
    'age': 25,
    'weight': 75.0,
    'height': 175.0,
    'unitWeight': 'kg',
    'unitDistance': 'km',
    'calorieTarget': 2200,
    'xp': 0,
    'muscleVolumeScore': <String, double>{},
  });

  settings.put('firstRun', false);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await _ensureBoxes();
  await _firstRunLoad();
  runApp(const ProviderScope(child: FitApp()));
}

class FitApp extends ConsumerWidget {
  const FitApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Hive.box('settings').get('darkMode', defaultValue: false);
    return MaterialApp.router(
      title: 'FitApp',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
    );
  }
}
