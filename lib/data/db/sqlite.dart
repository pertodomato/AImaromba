import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openFitDb() async {
  final dbPath = kIsWeb ? 'fitapp.db' : join(await getDatabasesPath(), 'fitapp.db');
  return openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS profiles(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
    },
  );
}

/// Testa a abertura e uma operação simples
Future<void> smokeTest() async {
  final db = await openFitDb();
  await db.insert('profiles', {'name': 'Default'}, conflictAlgorithm: ConflictAlgorithm.ignore);
  await db.query('profiles');
  await db.close();
}
