// lib/features/3_planner/presentation/pages/controllers/planner_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../application/planner_orchestrator.dart';
import '../../../domain/value_objects/question.dart';

enum PlanUiStep { goal, questions, summary, generating, error }

class PlannerState {
  final PlanUiStep step;
  final String? message;
  final double? progress;
  final List<Question> questions;
  final Map<String, String> summaries; // workout_summary, nutrition_summary
  const PlannerState({
    required this.step,
    this.message,
    this.progress,
    this.questions = const [],
    this.summaries = const {},
  });

  PlannerState copyWith({
    PlanUiStep? step,
    String? message,
    double? progress,
    List<Question>? questions,
    Map<String, String>? summaries,
  }) =>
      PlannerState(
        step: step ?? this.step,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        questions: questions ?? this.questions,
        summaries: summaries ?? this.summaries,
      );

  static PlannerState initial() => const PlannerState(step: PlanUiStep.goal);
}

class PlannerController extends ChangeNotifier {
  final PlannerOrchestrator orchestrator;
  PlannerState _state = PlannerState.initial();
  PlannerState get state => _state;
  final _uuid = const Uuid();

  PlannerController({required this.orchestrator});

  void _set(PlannerState s) {
    // LOG
    // ignore: avoid_print
    print('[PlannerState] step=${s.step} msg=${s.message ?? ""} prog=${s.progress ?? ""}');
    _state = s;
    notifyListeners();
  }

  Future<void> fetchQuestions({
    required Map<String, Object?> userProfile,
    required String goal,
  }) async {
    _set(_state.copyWith(
        step: PlanUiStep.generating, message: 'IA preparando perguntas...', progress: null));
    try {
      final raw =
          await orchestrator.generateQuestions(userProfile: userProfile, userGoal: goal);
      final qs = raw.map((m) => Question.fromMap(m)).toList();
      _set(_state.copyWith(
          step: PlanUiStep.questions, questions: qs, message: null, progress: null));
    } catch (e) {
      _set(_state.copyWith(step: PlanUiStep.error, message: 'Erro ao gerar perguntas: $e'));
    }
  }

  Future<void> generateSummaries({
    required Map<String, Object?> userProfile,
    required String goal,
    required Map<String, String> answers,
  }) async {
    _set(_state.copyWith(step: PlanUiStep.generating, message: 'Gerando resumo...', progress: null));
    try {
      final s = await orchestrator.generateSummaries(
          userProfile: userProfile, userGoal: goal, answers: answers);
      _set(_state.copyWith(step: PlanUiStep.summary, summaries: s, message: null));
    } catch (e) {
      _set(_state.copyWith(step: PlanUiStep.error, message: 'Erro ao gerar resumo: $e'));
    }
  }

  /// Agora retorna `bool` para a tela saber se deu tudo certo.
  Future<bool> confirmAndBuild({
    required Map<String, Object?> userProfile,
    required Map<String, String> answers,
  }) async {
    _set(_state.copyWith(
        step: PlanUiStep.generating, message: 'Construindo treino e dieta...', progress: 0.0));
    try {
      // Treino
      await for (final ev
          in orchestrator.buildWorkoutPlan(userProfile: userProfile, answers: answers)) {
        _set(_state.copyWith(step: PlanUiStep.generating, message: ev.message, progress: ev.progress));
      }
      // Dieta
      await for (final ev
          in orchestrator.buildDietPlan(userProfile: userProfile, answers: answers)) {
        _set(_state.copyWith(step: PlanUiStep.generating, message: ev.message, progress: ev.progress));
      }
      _set(_state.copyWith(step: PlanUiStep.goal, message: null, progress: null));
      // ignore: avoid_print
      print('== confirmAndBuild: SUCCESS');
      return true;
    } catch (e, st) {
      // ignore: avoid_print
      print('== confirmAndBuild: ERROR\n$e\n$st');
      _set(_state.copyWith(step: PlanUiStep.error, message: 'Erro ao construir planos: $e'));
      return false;
    }
  }
}
