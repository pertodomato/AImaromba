import 'package:flutter/material.dart';

class WeeklyDeltaChart extends StatelessWidget {
  final List<double> deltas; // 7 valores: <0 déficit, >0 superávit
  const WeeklyDeltaChart({super.key, required this.deltas});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Bars(deltas, Theme.of(context)));
}

class _Bars extends CustomPainter {
  final List<double> ds; final ThemeData theme;
  _Bars(this.ds, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dayW = w / (ds.isEmpty ? 1 : ds.length);
    final axis = Paint()..color = theme.colorScheme.outline..strokeWidth = 1;
    canvas.drawLine(Offset(0, h/2), Offset(w, h/2), axis);

    final barPaint = Paint();
    final maxAbs = (ds.isEmpty ? 1 : ds.map((e)=> e.abs()).reduce((a,b)=> a>b?a:b)).clamp(1, 2000);
    for (int i=0;i<ds.length;i++){
      final v = ds[i];
      final barH = (h/2) * (v.abs()/maxAbs);
      final x = i*dayW + dayW*0.2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, v>=0 ? h/2 - barH : h/2, dayW*0.6, barH),
        const Radius.circular(6),
      );
      barPaint.color = v>=0 ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer;
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Bars old) => old.ds != ds;
}
