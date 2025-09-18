import 'package:flutter/material.dart';
import 'package:fitapp/core/models/ai_plan.dart';
import 'package:fitapp/core/services/plan_explainer.dart';

class PlanSummaryPage extends StatelessWidget {
  const PlanSummaryPage({super.key, required this.plan});
  final AiPlan plan;

  @override
  Widget build(BuildContext context) {
    final explainer = PlanExplainer();
    final summary = explainer.summary(plan);
    final byDay = explainer.dayBreakdown(plan);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano gerado'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Descrição do que a IA gerou — 100% baseado no objeto real
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detalhamento por dia
          ...byDay.map((txt) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(txt),
            ),
          )),

          const SizedBox(height: 16),

          if ((plan.notes ?? '').isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Observações da IA: ${plan.notes!}'),
              ),
            ),
        ],
      ),
    );
  }
}
