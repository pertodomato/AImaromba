// lib/core/utils/muscle_validation.dart

// IDs válidos do muscle_selector
const Set<String> kValidGroupIds = {
  'neck','chest','upper_chest','lower_chest',
  'anterior_deltoid','lateral_deltoid','posterior_deltoid',
  'biceps','triceps','forearms','abs','obliques',
  'lats','traps','upper_back','lower_back',
  'glutes','quadriceps','hamstrings','adductors','abductors','calves',
};

bool isValidGroupId(String id) => kValidGroupIds.contains(id);

// slug simples: tira acento, minúsculas, troca não-alfanum por "_"
String _slug(String s) {
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
  return buf
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

// aliases PT/EN -> id canônico (chaves já “slugadas”)
final Map<String, String> _aliasToId = {
  for (final id in kValidGroupIds) id: id,
  _slug('peitoral'): 'chest',
  _slug('peito'): 'chest',
  _slug('deltoide anterior'): 'anterior_deltoid',
  _slug('deltoide lateral'): 'lateral_deltoid',
  _slug('deltoide posterior'): 'posterior_deltoid',
  _slug('tríceps'): 'triceps',
  _slug('triceps'): 'triceps',
  _slug('bíceps'): 'biceps',
  _slug('biceps'): 'biceps',
  _slug('dorsal'): 'lats',
  _slug('costas'): 'lats',
  _slug('lombar'): 'lower_back',
  _slug('posterior coxa'): 'hamstrings',
  _slug('isquiotibiais'): 'hamstrings',
  _slug('quadríceps'): 'quadriceps',
  _slug('quadriceps'): 'quadriceps',
  _slug('glúteos'): 'glutes',
  _slug('gluteos'): 'glutes',
  _slug('abdômen'): 'abs',
  _slug('abdomen'): 'abs',
  _slug('abdominais'): 'abs',
  _slug('oblíquos'): 'obliques',
  _slug('obliquos'): 'obliques',
  _slug('antebraço'): 'forearms',
  _slug('antebraco'): 'forearms',
  _slug('panturrilha'): 'calves',
  _slug('trapézio'): 'traps',
  _slug('trapezio'): 'traps',
  _slug('adutores'): 'adductors',
  _slug('abdutores'): 'abductors',
};

String? toGroupId(String name) {
  final key = _slug(name);
  return _aliasToId[key];
}

Iterable<String> toGroupIds(Iterable<String> names) {
  final out = <String>{};
  for (final n in names) {
    final id = toGroupId(n);
    if (id != null) out.add(id);
  }
  return out;
}

// ---- ALIASES p/ código legado ----
const Set<String> kAllowedMuscles = kValidGroupIds;
bool isValidMuscleName(String name) => toGroupId(name) != null;
