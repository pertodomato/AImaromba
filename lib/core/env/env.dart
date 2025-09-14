// lib/core/env/env.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Env {
  static const _storage = FlutterSecureStorage();
  static const _openAiApiKey = 'OPENAI_API_KEY';

  static Future<void> setOpenAiApiKey(String key) async {
    await _storage.write(key: _openAiApiKey, value: key);
  }

  static Future<String?> getOpenAiApiKey() async {
    return await _storage.read(key: _openAiApiKey);
  }
}