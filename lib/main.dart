// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/db/db_factory.dart';
import 'presentation/screens/dashboard_screen.dart'; // ajuste o caminho se necessário
import 'screens/nutrition/add_meal_route.dart';      // ajuste o caminho se necessário

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDbFactory(); // configura Drift (sqlite3.wasm no Web; nativo no mobile/desktop)
  runApp(const ProviderScope(child: FitApp()));
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'FitApp',
      theme: theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const DashboardScreen(),
        '/nutrition/add': (_) => const AddMealRoute(),
      },
    );
  }
}
