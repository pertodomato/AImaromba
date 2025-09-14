import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

Future<void> initDbFactory() async {
  // Desktop usa FFI; Android/iOS ficam com a factory padrão do sqflite
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
