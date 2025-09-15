import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get status => text()(); // 'active' | 'finished'
  DateTimeColumn get date => dateTime()();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  TextColumn get exerciseId => text()(); // ref Exercises.id
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  DateTimeColumn get timestamp => dateTime()();
}

class Exercises extends Table {
  TextColumn get id => text()(); // ex: "bench_press"
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()(); // breakfast/lunch/...
  IntColumn get calories => integer()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get productBarcode => text().nullable()();
}

@DriftDatabase(tables: [Workouts, WorkoutSets, Exercises, FoodLogs, Profiles])
class AppDatabase extends _$AppDatabase {
  // Um único caminho que funciona em todas as plataformas
  AppDatabase()
      : super(
          driftDatabase(
            name: 'fitapp.db',
            // No Web, informe onde estão os assets wasm/worker
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.dart.js'),
            ),
          ),
        );

  @override
  int get schemaVersion => 1;
}