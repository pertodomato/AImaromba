import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../widgets/app_drawer.dart';
import '../widgets/nutrition/add_meal_sheet.dart';
import '../../widgets/nutrition/routine_wizard.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  // ------- helpers de dados (Hive “cru” para reduzir acoplamento) -------
  String get _todayStr => DateTime.now().toIso8601String().substring(0, 10);

  Map<String, double> _totaisHoje() {
    final logs = Hive.box('foodlogs').values.where((e) => e['date'] == _todayStr);
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final e in logs) {
      kcal += (e['kcal'] as num).toDouble();
      p += (e['protein'] as num).toDouble();
      c += (e['carbs'] as num).toDouble();
      f += (e['fat'] as num).toDouble();
    }
    return {'kcal': kcal, 'p': p, 'c': c, 'f': f};
  }

  double _alvoKcal() {
    final prof = Hive.box('profile');
    return (prof.get('calorieTarget', defaultValue: 2000) as num).toDouble();
    // saldo = alvo - consumido (positivo == ainda pode comer)
  }

  List<Map<String, dynamic>> _logsRecentesAgrupados() {
    // agrupa por dia (desc), cada item: {"date": "YYYY-MM-DD", "items": [Map]}
    final all = Hive.box('foodlogs').values.cast<Map>().toList();
    all.sort((a, b) => (_toTs(b)).compareTo(_toTs(a)));
    final byDay = <String, List<Map>>{};
    for (final e in all) {
      final d = (e['date'] as String?) ?? _todayStr;
      byDay.putIfAbsent(d, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return days.map((d) => {'date': d, 'items': byDay[d]!}).toList();
  }

  int _toTs(Map m) {
    // compat: se não houver timestamp, usa ordem de inserção via hash
    return (m['timestamp'] as int?) ?? 0;
  }

  // rotinas simples: lê box 'nutrition_routines' (schema flexível)
  List<Map<String, dynamic>> _planejadasHoje() {
    final box = Hive.box('nutrition_routines');
    final items = <Map<String, dynamic>>[];
    final dow = (DateTime.now().weekday % 7); // 0=dom … 6=sab (compat)
    for (final v in box.values) {
      if (v is Map && v['items'] is List) {
        for (final it in v['items']) {
          final m = Map<String, dynamic>.from(it as Map);
          final iDow = (m['dow'] as num?)?.toInt();
          if (iDow == null || iDow == dow) items.add(m);
        }
      }
    }
    return items;
  }

  String _proximaRefeicaoNome() {
    final planned = _planejadasHoje();
    if (planned.isEmpty) return 'Nenhuma planejada';
    final eatenNames = Hive.box('foodlogs')
        .values
        .where((e) => e['date'] == _todayStr)
        .map((e) => (e['name'] ?? '').toString().toLowerCase())
        .toSet();

    for (final it in planned) {
      final name = (it['mealName'] ?? '').toString();
      if (name.isEmpty) continue;
      if (!eatenNames.contains(name.toLowerCase())) {
        final grams = (it['grams'] as num?)?.toDouble() ?? 0;
        return grams > 0 ? '$name — ${grams.round()} g' : name;
      }
    }
    return 'Tudo do dia já feito';
  }

  // criação de rotina com IA (descrição -> JSON) e salva no box
  Future<void> _criarOuAjustarRotinaIA() async {
  try {
    // Abre o assistente de rotina (IA) em modo de conversa
    await showRoutineWizard(context); // import: 'widgets/nutrition/routine_wizard.dart'
    if (!mounted) return;
    setState(() {}); // atualiza os cards (últimas rotinas, etc.)
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha ao abrir o assistente de rotina: $e')),
    );
  }
}

  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final totals = _totaisHoje();
    final target = _alvoKcal();
    final saldo = target - totals['kcal']!;
    final nextMeal = _proximaRefeicaoNome();
    final isWide = MediaQuery.of(context).size.width >= 1100;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // fila superior: Adicionar refeição | Próxima refeição
        Row(
          children: [
            Expanded(child: _AddMealCard(onAdd: () => showAddMealSheet(context))),
            const SizedBox(width: 12),
            Expanded(child: _NextMealCard(text: nextMeal)),
          ],
        ),
        const SizedBox(height: 12),

        // painel “calorias/hoje + evolução peso + criar rotina”
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoje', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _CaloriesTodayCard(totals: totals, target: target, saldo: saldo)),
                    const SizedBox(width: 12),
                    Expanded(child: const _WeightEvolutionCard()),
                  ],
                ),
                const SizedBox(height: 12),
                _RoutineCoachCard(onTapIA: _criarOuAjustarRotinaIA),
              ],
            ),
          ),
        ),
      ],
    );

    final rightHistory = _HistoryCard(itemsByDay: _logsRecentesAgrupados());

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrição')),
      drawer: const AppNavDrawer(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: leftColumn),
                  const SizedBox(width: 16),
                  // altura “fixa” confortável; o conteúdo interno rola
                  SizedBox(width: 420, child: rightHistory),
                ],
              )
            : ListView(
                children: [
                  leftColumn,
                  const SizedBox(height: 12),
                  rightHistory,
                ],
              ),
      ),
    );
  }
}

// ===================== Cards (UI) =====================

class _AddMealCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddMealCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adicionar refeição', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Foto/IA/Scanner ou Texto/IA/Manual — escolha no próximo passo.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextMealCard extends StatelessWidget {
  final String text;
  const _NextMealCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próxima refeição do dia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(text.isEmpty ? '—' : text, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _CaloriesTodayCard extends StatelessWidget {
  final Map<String, double> totals;
  final double target;
  final double saldo;
  const _CaloriesTodayCard({required this.totals, required this.target, required this.saldo});

  @override
  Widget build(BuildContext context) {
    final kc = totals['kcal']!.round();
    final p = totals['p']!;
    final c = totals['c']!;
    final f = totals['f']!;
    final color = saldo >= 0 ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Calorias de hoje', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text('$kc kcal', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Alvo: ${target.round()} kcal  •  '
            'Saldo: ${saldo >= 0 ? '+' : ''}${saldo.round()} kcal', style: TextStyle(color: color)),
        const SizedBox(height: 6),
        Text('P:${p.toStringAsFixed(1)}  C:${c.toStringAsFixed(1)}  G:${f.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _WeightEvolutionCard extends StatelessWidget {
  const _WeightEvolutionCard();

  List<double> _history() {
    // Busca em profile.weightHistory = [{"date":"YYYY-MM-DD","kg":70.2}, ...]
    final prof = Hive.box('profile');
    final list = (prof.get('weightHistory', defaultValue: const []) as List).cast<Map>();
    if (list.isEmpty) {
      final w = (prof.get('weight', defaultValue: 0) as num).toDouble();
      return w > 0 ? [w] : const [];
    }
    final xs = list.map((e) => (e['kg'] as num?)?.toDouble() ?? 0).where((v) => v > 0).toList();
    return xs;
  }

  @override
  Widget build(BuildContext context) {
    final data = _history();
    final target = (Hive.box('profile').get('targetWeight', defaultValue: 0) as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Evolução do peso', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: CustomPaint(painter: _Sparkline(data, target)),
        ),
        const SizedBox(height: 6),
        Text(
          target > 0 ? 'Meta: ${target.toStringAsFixed(1)} kg' : 'Defina a meta na tela Perfil',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
    );
  }
}

class _Sparkline extends CustomPainter {
  final List<double> ys;
  final double target;
  _Sparkline(this.ys, this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (ys.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: 'Sem dados'),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, h / 2 - tp.height / 2));
      return;
    }
    final mn = ys.reduce(min), mx = ys.reduce(max);
    double yOf(double v) => h - ((v - mn) / (mx == mn ? 1 : (mx - mn))) * h;

    final line = Paint()
      ..color = const Color(0xFF90CAF9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < ys.length; i++) {
      final x = w * (i / max(1, ys.length - 1));
      final y = yOf(ys[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);

    if (target > 0) {
      final ty = yOf(target);
      final dash = Paint()
        ..color = const Color(0xFF66BB6A)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, ty), Offset(w, ty), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _Sparkline old) =>
      old.ys != ys || old.target != target;
}

class _RoutineCoachCard extends StatelessWidget {
  final VoidCallback onTapIA;
  const _RoutineCoachCard({required this.onTapIA});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Criar/ajustar rotina com IA • Analisar adesão diária',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          FilledButton.tonal(
            onPressed: onTapIA,
            child: const Text('Abrir IA'),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> itemsByDay;
  const _HistoryCard({required this.itemsByDay});

  @override
  Widget build(BuildContext context) {
    // Card com ListView interno (rolagem própria)
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico de refeições', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 560, // no mobile esse card ocupa a largura total e rola dentro
              child: ListView.separated(
                itemCount: itemsByDay.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (_, i) {
                  final d = itemsByDay[i]['date'] as String;
                  final items = (itemsByDay[i]['items'] as List).cast<Map>();
                  final kcal = items.fold<num>(0, (s, e) => s + (e['kcal'] as num)).round();
                  return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('$d • $kcal kcal'),
                    children: items.map((e) {
                      final grams = (e['grams'] as num?)?.toDouble() ?? 0;
                      final name = (e['name'] ?? 'Refeição').toString();
                      final p = (e['protein'] as num).toDouble();
                      final c = (e['carbs'] as num).toDouble();
                      final f = (e['fat'] as num).toDouble();
                      final kc = (e['kcal'] as num).toDouble();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('• $name — ${grams.round()} g'),
                        subtitle: Text(
                          '${kc.round()} kcal  P:${p.toStringAsFixed(1)}  C:${c.toStringAsFixed(1)}  G:${f.toStringAsFixed(1)}',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
