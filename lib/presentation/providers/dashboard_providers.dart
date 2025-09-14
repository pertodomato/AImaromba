// lib/presentation/providers/database_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/db/sqlite.dart';

/// Abre um Database único e fecha no dispose.
/// Consuma com: ref.watch(databaseProvider).when(...)
final databaseProvider = FutureProvider<Database>((ref) async {
  final db = await openFitDb();
  ref.onDispose(() => db.close());
  return db;
});
