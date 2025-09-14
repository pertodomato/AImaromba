// lib/bootstrap_db.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> initDbFactory() async {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    await databaseFactoryFfiWeb.initWeb(wasmUri: 'sqlite3.wasm'); // precisa existir em /web
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android/iOS usam a factory padrão.
}
