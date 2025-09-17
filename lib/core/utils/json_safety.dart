import 'dart:convert';

/// Tenta decodificar JSON robustamente.
/// Remove lixo antes/depois, blocos ``` e vírgulas finais.
Map<String, dynamic> safeDecodeMap(String raw) {
  String s = raw.trim();

  // remove cercas de código
  if (s.startsWith('```')) {
    final i = s.indexOf('\n');
    if (i != -1) s = s.substring(i + 1);
    if (s.endsWith('```')) s = s.substring(0, s.length - 3);
  }

  // recorta do primeiro { ao último }
  final a = s.indexOf('{');
  final b = s.lastIndexOf('}');
  if (a != -1 && b != -1 && b > a) {
    s = s.substring(a, b + 1);
  }

  // remove vírgulas finais antes de colchetes/chaves
  s = s.replaceAll(RegExp(r',\s*([\}\]])'), r'$1');

  final obj = jsonDecode(s);
  if (obj is Map<String, dynamic>) return obj;
  throw const FormatException('JSON não é um objeto.');
}
