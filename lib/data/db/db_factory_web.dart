import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> initDbFactory() async {
  // Requer web/sqlite3.wasm e web/sqflite_sw.js (gerados pelo: dart run sqflite_common_ffi_web:setup)
  databaseFactory = databaseFactoryFfiWeb;
}
