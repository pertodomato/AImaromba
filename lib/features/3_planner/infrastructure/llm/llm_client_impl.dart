// lib/features/3_planner/infrastructure/llm/llm_client_impl.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fitapp/core/services/llm_service.dart';
import 'package:fitapp/core/utils/json_safety.dart';

class LLMClientImpl {
  final LLMService _llm;
  LLMClientImpl(this._llm);

  Future<Map<String, dynamic>> _callPrompt(
    String assetPath, Map<String, Object?> vars, {
    List<String>? imagesBase64,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    var prompt = raw;
    vars.forEach((k, v) {
      prompt = prompt.replaceAll('{$k}', v is String ? v : jsonEncode(v));
    });

    final resp = await _llm.getJson(prompt, images: null);
    return safeDecodeMap(resp);
  }

  // --------- TREINO ----------
  Future<Map<String, dynamic>> getWorkoutRoutine({
    required Map<String, Object?> userProfile,
    required List<Map<String, String>> userAnswers,
    required List<Map<String, String>> existingBlocks,
  }) {
    return _callPrompt(
      'assets/prompts/planner_get_routine.txt',
      {
        'user_profile': jsonEncode(userProfile),
        'user_answers': jsonEncode(userAnswers),
        'existing_blocks': jsonEncode(existingBlocks),
      },
    );
  }

  Future<Map<String, dynamic>> getWorkoutBlockStructure({
    required Map<String, String> blockPlaceholder,
    required List<Map<String, String>> existingDays,
  }) {
    return _callPrompt(
      'assets/prompts/planner_get_block_structure.txt',
      {
        'block_placeholder_json': jsonEncode(blockPlaceholder),
        'existing_days_json': jsonEncode(existingDays),
      },
    );
  }

  Future<Map<String, dynamic>> getWorkoutDaySessions({
    required Map<String, String> dayPlaceholder,
    required List<Map<String, String>> existingSessions,
    required List<Map<String, Object?>> existingExercises,
    required List<String> validMuscles,
  }) {
    return _callPrompt(
      'assets/prompts/planner_get_session_structure.txt',
      {
        'day_placeholder_json': jsonEncode(dayPlaceholder),
        'existing_sessions_json': jsonEncode(existingSessions),
        'existing_exercises_json': jsonEncode(existingExercises),
        'valid_muscles_json': jsonEncode(validMuscles),
      },
    );
  }

  Future<Map<String, dynamic>> getExerciseFromHint({
    required Map<String, Object?> hint,
    required List<String> validMuscles,
  }) {
    return _callPrompt(
      'assets/prompts/planner_get_exercise.txt',
      {
        'exercise_hint_json': jsonEncode(hint),
        'valid_muscles_json': jsonEncode(validMuscles),
      },
    );
  }

  // --------- NUTRIÇÃO ----------
  Future<Map<String, dynamic>> getDietRoutine({
    required Map<String, Object?> userProfile,
    required List<Map<String, String>> userAnswers,
    required List<Map<String, String>> existingDietBlocks,
  }) {
    return _callPrompt(
      'assets/prompts/diet_get_routine.txt',
      {
        'user_profile': jsonEncode(userProfile),
        'user_answers': jsonEncode(userAnswers),
        'existing_diet_blocks': jsonEncode(existingDietBlocks),
      },
    );
  }

  Future<Map<String, dynamic>> getDietBlockStructure({
    required Map<String, String> dietBlockPlaceholder,
    required List<Map<String, String>> existingDietDays,
    required List<String> userFoodPrefs,
  }) {
    return _callPrompt(
      'assets/prompts/diet_get_block_structure.txt',
      {
        'diet_block_placeholder_json': jsonEncode(dietBlockPlaceholder),
        'existing_diet_days': jsonEncode(existingDietDays),
        'user_food_prefs': jsonEncode(userFoodPrefs),
      },
    );
  }

  Future<Map<String, dynamic>> getDietDayPlan({
    required Map<String, Object?> userProfile,
    required String userGoal,
    required List<String> userFoodPrefs,
    required Map<String, String> dietDay,
    required List<Map<String, Object?>> existingMealsSummary,
    required Map<String, num> dayTargets,
  }) {
    return _callPrompt(
      'assets/prompts/diet_get_day_plan.txt',
      {
        'user_profile': jsonEncode(userProfile),
        'user_goal': userGoal,
        'user_food_prefs': jsonEncode(userFoodPrefs),
        'diet_day_json': jsonEncode(dietDay),
        'existing_meals_summary': jsonEncode(existingMealsSummary),
        'day_targets_json': jsonEncode(dayTargets),
      },
    );
  }
}
