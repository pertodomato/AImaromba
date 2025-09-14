import 'package:flutter/material.dart';

class HeaderCards extends StatelessWidget {
  final double kcalToday, p, c, f, targetKcal;
  final double weightNow, targetWeight;
  final bool weightTrendOk;
  const HeaderCards({
    super.key,
    required this.kcalToday, required this.p, required this.c, required this.f, required this.targetKcal,
    required this.weightNow, required this.targetWeight, required this.weightTrendOk,
  });

  @override
  Widget build(BuildContext context) {
    final over = (kcalToday - targetKcal).round();
    return Row(
      children: [
        Expanded(child: _Card(
          title: 'Hoje',
          big: '${kcalToday.round()} kcal',
          small: 'P:${p.toStringAsFixed(1)} C:${c.toStringAsFixed(1)} G:${f.toStringAsFixed(1)} • alvo ${targetKcal.round()}',
          icon: Icons.local_fire_department_outlined,
          color: Theme.of(context).colorScheme.primaryContainer,
          badge: over==0 ? 'OK' : (over>0? '+$over' : '$over'),
        )),
        const SizedBox(width: 12),
        Expanded(child: _Card(
          title: 'Peso',
          big: weightNow==0? '--' : '${weightNow.toStringAsFixed(1)} kg',
          small: targetWeight==0? 'sem meta' : 'meta ${targetWeight.toStringAsFixed(1)}',
          icon: weightTrendOk ? Icons.trending_down : Icons.trending_up,
          color: Theme.of(context).colorScheme.secondaryContainer,
          badge: weightTrendOk ? 'indo bem' : 'ajustar',
        )),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title, big, small, badge;
  final IconData icon;
  final Color color;
  const _Card({required this.title, required this.big, required this.small, required this.icon, required this.color, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                Text(big, style: Theme.of(context).textTheme.headlineSmall),
                Text(small, style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12),
              ),
              child: Text(badge, style: Theme.of(context).textTheme.labelSmall),
            )
          ],
        ),
      ),
    );
  }
}
