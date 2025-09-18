import 'package:fitapp/core/models/ai_plan.dart';

class PlanExplainer {
  String summary(AiPlan plan) {
    final b = StringBuffer();

    if (plan.goal != null) {
      b.writeln('Objetivo: ${plan.goal}.');
    }
    if (plan.experienceLevel != null) {
      b.writeln('Nível: ${plan.experienceLevel}.');
    }
    if (plan.mesocycleWeeks != null) {
      b.writeln('Mesociclo: ${plan.mesocycleWeeks} semanas.');
    }

    final days = plan.weekTemplate.length;
    if (days > 0) {
      b.writeln('Frequência semanal: $days ${days == 1 ? 'dia' : 'dias'}/semana.');
    }

    // Macros/Calorias
    final kcal = plan.dailyCalories ?? plan.macros?.calories;
    if (kcal != null) b.writeln('Calorias diárias alvo: ${kcal} kcal.');
    if (plan.macros != null) {
      final m = plan.macros!;
      final parts = <String>[];
      if (m.proteinG != null) parts.add('Proteína: ${m.proteinG} g');
      if (m.carbsG != null) parts.add('Carboidrato: ${m.carbsG} g');
      if (m.fatG != null) parts.add('Gordura: ${m.fatG} g');
      if (parts.isNotEmpty) b.writeln(parts.join(' · '));
      if (m.split != null) b.writeln('Split declarado: ${m.split}.');
    }

    // Focos por dia
    final focos = plan.weekTemplate.where((d) => (d.focus ?? '').isNotEmpty).map((d) => d.focus!).toList();
    if (focos.isNotEmpty) {
      b.writeln('Focos semanais: ${focos.join(', ')}.');
    }

    // Sinalização de intensidade (RPE/RIR)
    final intens = _intensityLine(plan);
    if (intens != null) b.writeln(intens);

    // Regras de progressão
    final prog = _progressionLine(plan);
    if (prog != null) b.writeln(prog);

    if ((plan.notes ?? '').isNotEmpty) {
      b.writeln('Notas: ${plan.notes!.trim()}');
    }

    return b.toString().trim();
  }

  String? _intensityLine(AiPlan plan) {
    final rpes = <double>[];
    final rirs = <double>[];
    for (final d in plan.weekTemplate) {
      for (final b in d.blocks) {
        if (b.rpe != null) rpes.add(b.rpe!);
        if (b.rir != null) rirs.add(b.rir!);
      }
    }
    if (rpes.isEmpty && rirs.isEmpty) return null;

    String stat(List<double> xs) {
      xs.sort();
      final mid = xs.length ~/ 2;
      final median = xs.length.isOdd ? xs[mid] : (xs[mid - 1] + xs[mid]) / 2;
      final min = xs.first, max = xs.last;
      return '${median.toStringAsFixed(1)} (min ${min.toStringAsFixed(1)} · máx ${max.toStringAsFixed(1)})';
    }

    final parts = <String>[];
    if (rpes.isNotEmpty) parts.add('RPE mediana ${stat(rpes)}');
    if (rirs.isNotEmpty) parts.add('RIR mediana ${stat(rirs)}');
    return 'Intensidade estimada: ${parts.join(' | ')}.';
  }

  String? _progressionLine(AiPlan plan) {
    if (plan.progression.isEmpty) return null;
    final labels = plan.progression.map((p) {
      switch (p.type) {
        case 'double_progression':
          final lo = p.params?['repsMin'] ?? p.params?['min'] ?? '?';
          final hi = p.params?['repsMax'] ?? p.params?['max'] ?? '?';
          return 'Dupla progressão (${lo}-${hi} reps → +carga)';
        case 'linear_load':
          final inc = p.params?['increment'] ?? '+';
          return 'Linear de carga (incremento $inc)';
        case 'wave':
          final w = p.params?['waves'] ?? 1;
          return 'Ondulatória ($w ondas)';
        default:
          return p.type;
      }
    }).toList();
    return 'Regras de progressão: ${labels.join(', ')}.';
  }

  /// Texto por dia com exercícios e parâmetros, extraído do plano real.
  List<String> dayBreakdown(AiPlan plan) {
    final out = <String>[];
    for (final d in plan.weekTemplate) {
      final sb = StringBuffer();
      sb.write('${d.day}');
      if ((d.focus ?? '').isNotEmpty) sb.write(' — ${d.focus}');
      sb.writeln(':');
      for (final b in d.blocks) {
        final bits = <String>[];
        bits.add(b.name);
        if (b.sets != null) bits.add('${b.sets}x');
        if ((b.reps ?? '').isNotEmpty) bits.add('${b.reps}');
        if (b.rpe != null) bits.add('RPE ${b.rpe}');
        if (b.rir != null) bits.add('RIR ${b.rir}');
        if (b.restSec != null) bits.add('Desc ${b.restSec}s');
        if ((b.tempo ?? '').isNotEmpty) bits.add('Tempo ${b.tempo}');
        sb.writeln(' • ${bits.join(' · ')}');
      }
      out.add(sb.toString().trimRight());
    }
    return out;
  }
}
