// lib/core/models/ai_plan.dart
import 'package:flutter/foundation.dart';

class AiPlan {
  AiPlan({
    required this.id,
    required this.createdAt,
    // MUDANÇA 1: Adicionados os campos para o resumo textual
    this.workoutSummary,
    this.nutritionSummary,
    this.goal,
    this.experienceLevel,
    this.mesocycleWeeks,
    this.macros,
    this.weekTemplate = const [],
    this.progression = const [],
    this.notes,
    this.dailyCalories,
  });

  final String id;
  final DateTime createdAt;
  
  // MUDANÇA 2: Campos para o resumo
  final String? workoutSummary;
  final String? nutritionSummary;

  final String? goal;
  final String? experienceLevel;
  final int? mesocycleWeeks;
  final int? dailyCalories;

  final AiMacroTarget? macros;
  final List<AiWorkoutDay> weekTemplate;
  final List<ProgressionRule> progression;
  final String? notes;

  factory AiPlan.fromMap(Map<String, dynamic> m) {
    AiMacroTarget? macros;
    if (m['macros'] is Map) {
      macros = AiMacroTarget.fromMap(Map<String, dynamic>.from(m['macros']));
    }

    final week = <AiWorkoutDay>[];
    final wt = (m['weekTemplate'] ?? m['week'] ?? m['days'] ?? []) as List?;
    if (wt != null) {
      for (final d in wt) {
        if (d is Map<String, dynamic>) week.add(AiWorkoutDay.fromMap(d));
        else if (d is Map) week.add(AiWorkoutDay.fromMap(Map<String, dynamic>.from(d)));
      }
    }

    final prog = <ProgressionRule>[];
    final pr = (m['progression'] ?? m['progressionRules'] ?? []) as List?;
    if (pr != null) {
      for (final p in pr) {
        if (p is Map<String, dynamic>) prog.add(ProgressionRule.fromMap(p));
        else if (p is Map) prog.add(ProgressionRule.fromMap(Map<String, dynamic>.from(p)));
      }
    }

    return AiPlan(
      id: (m['id'] ?? m['planId'] ?? m['uuid'] ?? '').toString(),
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
      
      // MUDANÇA 3: Lendo os campos de resumo do JSON
      workoutSummary: m['workout_summary']?.toString(),
      nutritionSummary: m['nutrition_summary']?.toString(),

      goal: m['goal']?.toString(),
      experienceLevel: m['experienceLevel']?.toString() ?? m['level']?.toString(),
      mesocycleWeeks: _toInt(m['mesocycleWeeks'] ?? m['weeks']),
      dailyCalories: _toInt(m['dailyCalories'] ?? m['calories']),
      macros: macros,
      weekTemplate: week,
      progression: prog,
      notes: m['notes']?.toString() ?? m['rationale']?.toString(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

class AiMacroTarget {
  AiMacroTarget({this.calories, this.proteinG, this.carbsG, this.fatG, this.split});
  final int? calories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final String? split; // ex: "40/30/30"

  factory AiMacroTarget.fromMap(Map<String, dynamic> m) => AiMacroTarget(
    calories: AiPlan._toInt(m['calories'] ?? m['kcal']),
    proteinG: AiPlan._toInt(m['protein'] ?? m['proteinG']),
    carbsG: AiPlan._toInt(m['carbs'] ?? m['carbohydrate'] ?? m['carbsG']),
    fatG: AiPlan._toInt(m['fat'] ?? m['fatG']),
    split: m['split']?.toString(),
  );
}

class AiWorkoutDay {
  AiWorkoutDay({required this.day, this.focus, this.blocks = const []});
  final String day;
  final String? focus;
  final List<AiExerciseBlock> blocks;

  factory AiWorkoutDay.fromMap(Map<String, dynamic> m) {
    final blocks = <AiExerciseBlock>[];
    final b = (m['blocks'] ?? m['exercises'] ?? []) as List?;
    if (b != null) {
      for (final it in b) {
        if (it is Map<String, dynamic>) blocks.add(AiExerciseBlock.fromMap(it));
        else if (it is Map) blocks.add(AiExerciseBlock.fromMap(Map<String, dynamic>.from(it)));
      }
    }
    return AiWorkoutDay(
      day: m['day']?.toString() ?? m['name']?.toString() ?? 'Dia',
      focus: m['focus']?.toString(),
      blocks: blocks,
    );
  }
}

class AiExerciseBlock {
  AiExerciseBlock({
    required this.name,
    this.exerciseId,
    this.sets,
    this.reps,
    this.rpe,
    this.rir,
    this.restSec,
    this.tempo,
  });

  final String name;
  final String? exerciseId;
  final int? sets;
  final String? reps;
  final double? rpe;
  final double? rir;
  final int? restSec;
  final String? tempo;

  factory AiExerciseBlock.fromMap(Map<String, dynamic> m) => AiExerciseBlock(
    name: m['name']?.toString() ?? m['exercise']?.toString() ?? 'Exercício',
    exerciseId: m['exerciseId']?.toString(),
    sets: AiPlan._toInt(m['sets']),
    reps: m['reps']?.toString(),
    rpe: double.tryParse(m['rpe']?.toString() ?? ''),
    rir: double.tryParse(m['rir']?.toString() ?? ''),
    restSec: AiPlan._toInt(m['rest'] ?? m['restSec']),
    tempo: m['tempo']?.toString(),
  );
}

class ProgressionRule {
  ProgressionRule({required this.type, this.params});
  final String type;
  final Map<String, dynamic>? params;

  factory ProgressionRule.fromMap(Map<String, dynamic> m) => ProgressionRule(
    type: m['type']?.toString() ?? 'custom',
    params: m['params'] is Map<String, dynamic>
      ? m['params'] as Map<String, dynamic>
      : (m['params'] is Map ? Map<String, dynamic>.from(m['params']) : null),
  );
}