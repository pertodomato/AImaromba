// lib/data/repositories/implementations/profile_repository_impl.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';

import '../../../data/db/app_database.dart';
import '../profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final AppDatabase _db;
  ProfileRepositoryImpl(this._db);

  @override
  Future<Profile> getActive() async {
    // Para simplificar, sempre pegamos o primeiro perfil
    final profileData = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    if (profileData == null) {
      // Se não houver nenhum, cria um padrão e retorna
      await _db.into(_db.profiles).insert(const ProfilesCompanion());
      return getActive();
    }
    return Profile(
        id: profileData.id,
        name: profileData.name,
        locale: Locale(profileData.locale.split('_').first, profileData.locale.split('_').last));
  }

  @override
  Future<bool> isFirstRun() async {
    final count = await (_db.selectOnly(_db.profiles)..addColumns([_db.profiles.id.count()])).getSingle();
    return count.read(_db.profiles.id.count()) == 0;
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    await (_db.update(_db.profiles)..where((p) => p.id.equals(profile.id))).write(
      ProfilesCompanion(
        name: Value(profile.name),
      ),
    );
  }

  @override
  Future<void> seedInitialData() async {
    // 1. Popular exercícios
    final exStr = await rootBundle.loadString('assets/exercise_db.json');
    final exList = jsonDecode(exStr) as List;
    final exercises = exList.map((e) => ExercisesCompanion.insert(
      id: e['id'],
      name: e['name'],
      muscleGroup: (e['primary'] as List).join(', '),
      rawData: jsonEncode(e),
    ));
    await _db.batch((batch) => batch.insertAll(_db.exercises, exercises));

    // 2. Salvar benchmarks (usaremos sync_meta para isso)
    final benchStr = await rootBundle.loadString('assets/benchmarks.json');
    await _db.into(_db.syncMeta).insert(SyncMetaCompanion.insert(
      key: 'benchmarks',
      value: benchStr,
    ));

    // 3. Salvar dados de alimentos (TACO) em Foods
    final foodStr = await rootBundle.loadString('assets/taco.json');
    final foodList = jsonDecode(foodStr) as List;
    final foods = foodList.map((f) => FoodsCompanion.insert(
      name: f['name'] ?? 'N/A',
      kcal: (f['kcal'] as num? ?? 0).toDouble(),
      protein: (f['protein'] as num? ?? 0).toDouble(),
      carbs: (f['carbs'] as num? ?? 0).toDouble(),
      fat: (f['fat'] as num? ?? 0).toDouble(),
      servingSize: 100, // TACO é por 100g
      servingUnit: 'g',
    ));
    await _db.batch((batch) => batch.insertAll(_db.foods, foods));

    // 4. Criar perfil inicial
    await _db.into(_db.profiles).insert(ProfilesCompanion.insert(
        name: 'Usuário',
        locale: 'pt_BR',
        gender: const Value('M'),
        age: const Value(25),
        weight: const Value(75.0),
        height: const Value(175.0)));
    
    // 5. Definir meta nutricional padrão
    final profile = await getActive();
    await _db.into(_db.nutritionGoals).insert(NutritionGoalsCompanion.insert(
      profileId: profile.id,
      kcal: 2200,
      protein: 150,
      carbs: 250,
      fat: 60,
    ));
  }

  @override
  Future<void> setLocale(String localeCode) async {
    final profile = await getActive();
    await (_db.update(_db.profiles)..where((p) => p.id.equals(profile.id))).write(
      ProfilesCompanion(locale: Value(localeCode)),
    );
  }
}