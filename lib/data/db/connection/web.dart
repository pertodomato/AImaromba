// lib/data/db/connection/web.dart

import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'package:sqlite3_wasm/sqlite3_wasm.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    // ESTA É A LINHA-CHAVE:
    final response = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    
    final sqlite3 = response.sqlite3;
    
    return WebDatabase.withStorage(
      await DriftWebStorage.indexedDb('fitapp_db'),
      sqlite3: sqlite3,
    );
  });
}