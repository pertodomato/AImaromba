// lib/features/2_profile/presentation/pages/plan_summary_page.dart

import 'package:flutter/material.dart';
import 'package:fitapp/core/models/ai_plan.dart';

class PlanSummaryPage extends StatelessWidget {
  final AiPlan plan;
  final VoidCallback onConfirm;

  const PlanSummaryPage({
    super.key,
    required this.plan,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do Seu Novo Plano'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSummaryCard(
            context,
            title: 'Plano de Treino',
            // MUDANÇA: Adicionado `?? ''` para tratar valores nulos
            summary: plan.workoutSummary ?? 'A IA não forneceu um resumo para o treino.',
            icon: Icons.fitness_center,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            context,
            title: 'Plano de Nutrição',
            // MUDANÇA: Adicionado `?? ''` para tratar valores nulos
            summary: plan.nutritionSummary ?? 'A IA não forneceu um resumo para a nutrição.',
            icon: Icons.restaurant,
            color: Colors.orangeAccent,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirmar e Criar Plano Completo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
          ),
          onPressed: onConfirm,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String summary,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const Divider(height: 24),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}