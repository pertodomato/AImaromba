import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meal.dart';
import '../../models/meal_log.dart';
import '../../providers/nutrition_providers.dart';
import '../../services/nutrition/nutrition_repository.dart';

class DayMealsSection extends ConsumerWidget {
  final List<Map<String, dynamic>> planned;
  final List<MealLog> consumed;
  const DayMealsSection({super.key, required this.planned, required this.consumed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refeições do dia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _PlannedList(items: planned),
            const SizedBox(height: 8),
            _ConsumedList(logs: consumed),
          ],
        ),
      ),
    );
  }
}

class _PlannedList extends ConsumerWidget {
  final List<Map<String, dynamic>> items;
  const _PlannedList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const ListTile(title: Text('Nenhuma planejada para hoje'), dense: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Planejadas'),
        ...items.map((it) {
          final grams = (it['grams'] as num?)?.toDouble() ?? 100;
          final mealId = (it['mealId'] ?? '').toString();
          final mealName = (it['mealName'] ?? 'Refeição').toString();
          final displayName = mealName.isNotEmpty ? mealName : mealId;

          return ListTile(
            dense: true,
            title: Text('• $displayName — ${grams.round()} g'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                final repo = ref.read(repoProvider);
                Meal? m = mealId.isNotEmpty ? await repo.getMeal(mealId) : null;
                m ??= Meal(
                  id: 'tmp_${DateTime.now().microsecondsSinceEpoch}',
                  name: mealName,
                  kcalPer100: 150,
                  pPer100: 10,
                  cPer100: 20,
                  fPer100: 5,
                );
                await repo.addLog(meal: m, grams: grams);

                // invalida os dados da tela
                ref.invalidate(consumedMealsTodayProvider);
                ref.invalidate(plannedMealsTodayProvider);
                ref.invalidate(todaySummaryProvider);
                ref.invalidate(weeklyDeltaProvider);
                ref.invalidate(weightProgressProvider);
              },
              child: const Text('Marcar como feita'),
            ),
          );
        }),
      ],
    );
  }
}

class _ConsumedList extends StatelessWidget {
  final List<MealLog> logs;
  const _ConsumedList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const ListTile(title: Text('Nada consumido ainda'), dense: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Consumidas'),
        ...logs.map(
          (l) => ListTile(
            dense: true,
            title: Text('• ${l.mealName} — ${l.grams.round()} g'),
            subtitle: Text(
              '${l.kcal.round()} kcal  '
              'P:${l.p.toStringAsFixed(1)}  '
              'C:${l.c.toStringAsFixed(1)}  '
              'G:${l.f.toStringAsFixed(1)}',
            ),
          ),
        ),
      ],
    );
  }
}
