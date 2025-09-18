// plan_parser.dart
import 'package:fitapp/core/models/ai_plan.dart';

class PlanParser {
  AiPlan parse(Map<String, dynamic> json) {
    // Parser tolerante centralizado (chama AiPlan.fromMap)
    return AiPlan.fromMap(json);
  }
}
