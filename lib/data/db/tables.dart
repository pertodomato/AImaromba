// lib/data/db/tables.dart
part of 'app_database.dart';

// id é autoincremento por padrão

class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant('Default Profile'))();
  TextColumn get locale => text().withDefault(const Constant('pt_BR'))();
  TextColumn get gender => text().withLength(min: 1, max: 1).nullable()();
  IntColumn get age => integer().nullable()();
  RealColumn get weight => real().nullable()();
  RealColumn get height => real().nullable()();
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, finished, cancelled
}

class Exercises extends Table {
  TextColumn get id => text().unique()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();
  // O JSON completo do exercício pode ser armazenado aqui
  TextColumn get rawData => text()(); 
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  IntColumn get rir => integer().nullable()(); // Rest in Reserve
  DateTimeColumn get timestamp => dateTime()();
}

class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get source => text()(); // "photo", "text", "barcode", "manual"
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get productBarcode => text().nullable()();
}

class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get barcode => text().unique().nullable()();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  RealColumn get servingSize => real()();
  TextColumn get servingUnit => text()(); // "g", "ml", "unit"
}

class NutritionGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get period => text().withDefault(const Constant('daily'))(); // daily, weekly
}

class SyncMeta extends Table {
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}