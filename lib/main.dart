// lib/main.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/db/db_factory.dart';

Future<void> _smokeTest() async {
  final db = await openDatabase('fitapp.db', version: 1, onCreate: (db, v) async {
    await db.execute('CREATE TABLE IF NOT EXISTS profiles(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
  });
  await db.insert('profiles', {'name': 'Default'}, conflictAlgorithm: ConflictAlgorithm.ignore);
  await db.query('profiles');
  await db.close();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDbFactory(); // definido via import condicional
  runApp(const FitApp());
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      cardTheme: const CardThemeData(),
    );

    return MaterialApp(
      title: 'FitApp',
      theme: theme,
      home: FutureBuilder<void>(
        future: _smokeTest(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('DB erro: ${snap.error}')));
          }
          return const Scaffold(body: Center(child: Text('OK')));
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
