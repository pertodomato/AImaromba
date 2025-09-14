class Meal {
  final String id;
  final String name;
  final double kcalPer100;
  final double pPer100;
  final double cPer100;
  final double fPer100;
  final double defaultPortion; // g
  final List<Map<String, dynamic>> ingredients;

  Meal({
    required this.id,
    required this.name,
    required this.kcalPer100,
    required this.pPer100,
    required this.cPer100,
    required this.fPer100,
    this.defaultPortion = 100,
    this.ingredients = const [],
  });

  factory Meal.fromMap(Map m) => Meal(
    id: (m['id'] ?? '').toString(),
    name: (m['name'] ?? 'Refeição').toString(),
    kcalPer100: ((m['kcalPer100'] ?? m['kcal'] ?? 0) as num).toDouble(),
    pPer100: ((m['pPer100'] ?? m['protein'] ?? 0) as num).toDouble(),
    cPer100: ((m['cPer100'] ?? m['carbs']   ?? 0) as num).toDouble(),
    fPer100: ((m['fPer100'] ?? m['fat']     ?? 0) as num).toDouble(),
    defaultPortion: ((m['defaultPortion'] ?? 100) as num).toDouble(),
    ingredients: List<Map<String, dynamic>>.from(m['ingredients'] as List? ?? const []),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name,
    'kcalPer100': kcalPer100, 'pPer100': pPer100, 'cPer100': cPer100, 'fPer100': fPer100,
    'defaultPortion': defaultPortion, 'ingredients': ingredients,
  };
}
