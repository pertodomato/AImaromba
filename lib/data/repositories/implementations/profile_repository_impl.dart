// lib/data/repositories/implementations/profile_repository_impl.dart
import 'dart:convert';
import 'dart:ui' show Locale;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../profile_repository.dart'; // mantém sua interface ProfileRepository e entidade Profile

class ProfileRepositoryImpl implements ProfileRepository {
  final Database _db;
  ProfileRepositoryImpl(this._db);

  // --- schema mínimo necessário para os métodos abaixo ---
  Future<void> _ensureSchema() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS profiles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        locale TEXT NOT NULL DEFAULT 'pt_BR',
        gender TEXT, age INTEGER, weight REAL, height REAL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS exercises(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        rawData TEXT NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT,
        barcode TEXT UNIQUE,
        kcal REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        servingSize REAL NOT NULL,
        servingUnit TEXT NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        kcal REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        period TEXT NOT NULL DEFAULT 'daily'
      )
    ''');
    // As tabelas abaixo não são usadas aqui, mas já deixo criadas:
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS workouts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS workout_sets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        exerciseId TEXT NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        rir INTEGER,
        timestamp TEXT NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS food_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        source TEXT NOT NULL,
        kcal REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        notes TEXT,
        productBarcode TEXT
      )
    ''');
  }

  @override
  Future<Profile> getActive() async {
    await _ensureSchema();
    final rows = await _db.query('profiles', limit: 1);
    if (rows.isEmpty) {
      // cria default e retorna
      final id = await _db.insert('profiles', {
        'name': 'Usuário',
        'locale': 'pt_BR',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final row = await _db.query('profiles',
          where: 'id=?', whereArgs: [id], limit: 1);
      final r = row.first;
      final parts = (r['locale'] as String).split('_');
      return Profile(
        id: r['id'] as int,
        name: r['name'] as String,
        locale: Locale(parts.first, parts.length > 1 ? parts.last : ''),
      );
    }
    final r = rows.first;
    final parts = (r['locale'] as String).split('_');
    return Profile(
      id: r['id'] as int,
      name: r['name'] as String,
      locale: Locale(parts.first, parts.length > 1 ? parts.last : ''),
    );
  }

  @override
  Future<bool> isFirstRun() async {
    await _ensureSchema();
    final res = await _db.rawQuery('SELECT COUNT(*) AS c FROM profiles');
    final c = (res.first['c'] as int?) ?? Sqflite.firstIntValue(res) ?? 0;
    return c == 0;
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    await _ensureSchema();
    await _db.update(
      'profiles',
      {'name': profile.name},
      where: 'id=?',
      whereArgs: [profile.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> seedInitialData() async {
    await _ensureSchema();

    final exStr = await rootBundle.loadString('assets/exercise_db.json');
    final benchStr = await rootBundle.loadString('assets/benchmarks.json');
    final foodStr = await rootBundle.loadString('assets/taco.json');

    final exList = (jsonDecode(exStr) as List).cast<Map<String, dynamic>>();
    final foodList = (jsonDecode(foodStr) as List).cast<Map<String, dynamic>>();

    await _db.transaction((txn) async {
      final b = txn.batch();

      // exercises
      for (final e in exList) {
        final id = e['id'] as String;
        final name = (e['name'] ?? 'N/A') as String;
        final muscleGroup = ((e['primary'] as List?) ?? const [])
            .map((x) => x.toString())
            .join(', ');
        b.insert(
          'exercises',
          {
            'id': id,
            'name': name,
            'muscleGroup': muscleGroup,
            'rawData': jsonEncode(e),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // sync_meta: benchmarks
      b.insert(
        'sync_meta',
        {'key': 'benchmarks', 'value': benchStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // foods
      for (final f in foodList) {
        b.insert(
          'foods',
          {
            'name': (f['name'] ?? 'N/A').toString(),
            'brand': f['brand']?.toString(),
            'barcode': f['barcode']?.toString(),
            'kcal': (f['kcal'] as num? ?? 0).toDouble(),
            'protein': (f['protein'] as num? ?? 0).toDouble(),
            'carbs': (f['carbs'] as num? ?? 0).toDouble(),
            'fat': (f['fat'] as num? ?? 0).toDouble(),
            'servingSize': 100.0,
            'servingUnit': 'g',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // perfil inicial se não existir
      final count = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM profiles'),
          ) ??
          0;
      int profileId;
      if (count == 0) {
        profileId = await txn.insert('profiles', {
          'name': 'Usuário',
          'locale': 'pt_BR',
          'gender': 'M',
          'age': 25,
          'weight': 75.0,
          'height': 175.0,
        });
      } else {
        final row = await txn.query('profiles', limit: 1);
        profileId = row.first['id'] as int;
      }

      // metas nutricionais padrão
      b.insert(
        'nutrition_goals',
        {
          'profileId': profileId,
          'kcal': 2200.0,
          'protein': 150.0,
          'carbs': 250.0,
          'fat': 60.0,
          'period': 'daily',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await b.commit(noResult: true);
    });
  }

  @override
  Future<void> setLocale(String localeCode) async {
    await _ensureSchema();
    final p = await getActive();
    await _db.update(
      'profiles',
      {'locale': localeCode},
      where: 'id=?',
      whereArgs: [p.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}
