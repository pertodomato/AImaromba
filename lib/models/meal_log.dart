class MealLog {
  final int ts;
  final String date;     // YYYY-MM-DD
  final String mealId;  // pode ser vazio
  final String mealName;
  final double grams;
  final double kcal, p, c, f;

  MealLog({
    required this.ts,
    required this.date,
    required this.mealId,
    required this.mealName,
    required this.grams,
    required this.kcal, required this.p, required this.c, required this.f,
  });

  factory MealLog.fromMap(Map m) => MealLog(
    ts: (m['ts'] ?? m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch) as int,
    date: (m['date'] ?? '').toString(),
    mealId: (m['mealId'] ?? '').toString(),
    mealName: (m['mealName'] ?? m['name'] ?? 'Refeição').toString(),
    grams: ((m['grams'] ?? 0) as num).toDouble(),
    kcal: ((m['kcal'] ?? 0) as num).toDouble(),
    p: ((m['p'] ?? m['protein'] ?? 0) as num).toDouble(),
    c: ((m['c'] ?? m['carbs']   ?? 0) as num).toDouble(),
    f: ((m['f'] ?? m['fat']     ?? 0) as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'ts': ts, 'date': date, 'mealId': mealId, 'mealName': mealName, 'grams': grams,
    'kcal': kcal, 'p': p, 'c': c, 'f': f,
  };
}
