import 'package:flutter/foundation.dart';

class AiPlan {
  AiPlan({
    required this.id,
    required this.createdAt,
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

  final String? goal;                 // ex: "Hipertrofia", "Emagrecimento"
  final String? experienceLevel;      // ex: "Iniciante", "Intermediário", "Avançado"
  final int? mesocycleWeeks;          // ex: 4, 6, 8
  final int? dailyCalories;           // kcal/dia se a IA retornar

  final AiMacroTarget? macros;        // macros absolutos (g) e/ou proporções
  final List<AiWorkoutDay> weekTemplate;
  final List<ProgressionRule> progression;
  final String? notes;

  /// Parser tolerante a chaves diferentes que a IA possa retornar.
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
  final String day;            // ex: "Segunda", "Terça", "Upper", "Lower"
  final String? focus;         // ex: "Empurrar", "Puxar", "Quadríceps"
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

  final String name;     // nome do exercício vindo da IA
  final String? exerciseId; // se já casou com seu catálogo/hive
  final int? sets;
  final String? reps;    // aceitar "8-10", "5", etc
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
  final String type; // ex: "double_progression", "linear_load", "wave"
  final Map<String, dynamic>? params;

  factory ProgressionRule.fromMap(Map<String, dynamic> m) => ProgressionRule(
    type: m['type']?.toString() ?? 'custom',
    params: m['params'] is Map<String, dynamic>
      ? m['params'] as Map<String, dynamic>
      : (m['params'] is Map ? Map<String, dynamic>.from(m['params']) : null),
  );
}
