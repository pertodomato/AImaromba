// lib/data/db/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Importa as tabelas que serão definidas em arquivos separados
part 'tables.dart';

// O part gerado pelo build_runner
part 'app_database.g.dart';

@DriftDatabase(tables: [
  Profiles,
  Workouts,
  Exercises,
  WorkoutSets,
  FoodLogs,
  Foods,
  NutritionGoals,
  SyncMeta
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // DAOs para acesso seguro às tabelas serão adicionados aqui posteriormente
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fitapp.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}