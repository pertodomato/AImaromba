// plan_validator.dart
import 'package:fitapp/core/models/ai_plan.dart';

class PlanValidator {
  bool isValid(AiPlan p) {
    if (p.id.isEmpty) return false;
    if (p.weekTemplate.isEmpty) return false;
    // valida pelo menos 1 bloco por dia
    final hasBlocks = p.weekTemplate.any((d) => d.blocks.isNotEmpty);
    if (!hasBlocks) return false;
    return true;
  }
}
