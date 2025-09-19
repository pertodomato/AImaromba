// lib/features/3_planner/application/ports/llm_client.dart
typedef Json = Map<String, dynamic>;
typedef Parser<T> = T Function(Json);

class PromptSpec<T> {
  final String id; // ex: workout.plan_overview.v1
  final String templateAssetPath; // assets/prompts/...
  final List<String> requiredKeys; // validação mínima
  final Parser<T> parser;
  const PromptSpec({
    required this.id,
    required this.templateAssetPath,
    required this.requiredKeys,
    required this.parser,
  });
}

abstract class LLMClient {
  Future<T> generate<T>({
    required PromptSpec<T> spec,
    required Map<String, Object?> vars,
  });
}
