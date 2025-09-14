// lib/presentation/providers/database_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';

/// Provider global e singleton para a instância do banco de dados.
final databaseProvider = Provider<AppDatabase>((ref) {
  // O banco de dados é instanciado aqui e sua instância é compartilhada
  // por todos os repositórios e DAOs que precisarem dela.
  final db = AppDatabase();
  
  // Adiciona um listener para fechar o banco de dados quando o provider for destruído.
  ref.onDispose(() => db.close());

  return db;
});