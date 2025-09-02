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

  final profile = Hive.box('profile');
  profile.putAll({
    'gender': 'M', 'age': 25, 'weight': 75.0, 'height': 175.0,
    'unitWeight': 'kg', 'unitDistance': 'km', 'calorieTarget': 2200,
    'xp': 0, 'muscleVolumeScore': <String, double>{},
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
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.tealAccent,
        brightness: Brightness.dark,
        background: const Color(0xFF1E1E1E),
        surface: const Color(0xFF2C2C2C),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2C2C2C),
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        color: Color(0xFF2C2C2C),
      ),
    );
    
    // ✅ MUDANÇA AQUI: O ValueListenableBuilder foi removido para simplificar
    // e o themeMode foi fixado em .dark.
    return MaterialApp.router(
      title: 'FitApp',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark, // Define o tema escuro como padrão
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
    );
  }
}