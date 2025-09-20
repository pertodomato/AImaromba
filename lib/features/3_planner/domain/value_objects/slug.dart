// lib/features/3_planner/domain/value_objects/slug.dart
/// Slug estável para reuso/idempotência.
/// Usa regra robusta e aceita hints para desambiguar.
String toSlug(String name, {List<String> hints = const []}) {
  String normalize(String s) {
    const map = {
      'á':'a','à':'a','ã':'a','â':'a','ä':'a',
      'é':'e','ê':'e','è':'e','ë':'e',
      'í':'i','ì':'i','î':'i','ï':'i',
      'ó':'o','ô':'o','õ':'o','ò':'o','ö':'o',
      'ú':'u','ù':'u','û':'u','ü':'u',
      'ç':'c','ñ':'n',
      'Á':'a','À':'a','Ã':'a','Â':'a','Ä':'a',
      'É':'e','Ê':'e','È':'e','Ë':'e',
      'Í':'i','Ì':'i','Î':'i','Ï':'i',
      'Ó':'o','Ô':'o','Õ':'o','Ò':'o','Ö':'o',
      'Ú':'u','Ù':'u','Û':'u','Ü':'u',
      'Ç':'c','Ñ':'n',
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      buf.write(map[c] ?? c);
    }
    final lowered = buf.toString().toLowerCase();
    final step1 = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '_'); // troca não-[a-z0-9] por "_"
    final step2 = step1.replaceAll(RegExp(r'_+'), '_');            // comprime "_"
    final step3 = step2.replaceAll(RegExp(r'^_+|_+$'), '');        // trim "_"
    return step3;
  }

  final base = normalize(name);
  if (hints.isEmpty) return base;
  final h = hints.map(normalize).where((e) => e.isNotEmpty).toList()..sort();
  return [base, ...h].join('__');
}
