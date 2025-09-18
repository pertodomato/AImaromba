// plan_normalizer.dart
import 'package:fitapp/core/models/ai_plan.dart';

class PlanNormalizer {
  AiPlan normalize(AiPlan p) {
    // Ex.: garantir capitalização de dias/focos sem alterar conteúdo
    final days = p.weekTemplate.map((d) {
      final fixedDay = d.day.trim().isEmpty ? 'Dia' : d.day.trim();
      return AiWorkoutDay(day: fixedDay, focus: d.focus, blocks: d.blocks);
    }).toList();

    return AiPlan(
      id: p.id,
      createdAt: p.createdAt,
      goal: p.goal?.trim(),
      experienceLevel: p.experienceLevel?.trim(),
      mesocycleWeeks: p.mesocycleWeeks,
      dailyCalories: p.dailyCalories ?? p.macros?.calories,
      macros: p.macros,
      weekTemplate: days,
      progression: p.progression,
      notes: p.notes?.trim(),
    );
  }
}
