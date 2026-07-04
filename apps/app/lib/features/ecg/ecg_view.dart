import 'package:flutter/material.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';

/// Renders a generated ECG trace on classic pink ECG-paper grid (prompt 14).
class EcgStrip extends StatelessWidget {
  const EcgStrip({super.key, required this.params, this.height = 180});
  final EcgGenParams params;
  final double height;

  @override
  Widget build(BuildContext context) {
    final samples = EcgGenerator.generate(params, sampleCount: 700, secondsPerScreen: 5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF0A0410),
        child: CustomPaint(painter: _EcgPainter(samples)),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.samples);
  final List<double> samples;

  @override
  void paint(Canvas canvas, Size size) {
    // Grid.
    final fine = Paint()..color = const Color(0x22FF5A7A)..strokeWidth = 0.5;
    final bold = Paint()..color = const Color(0x44FF5A7A)..strokeWidth = 1;
    const step = 12.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x % (step * 5) == 0) ? bold : fine);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y % (step * 5) == 0) ? bold : fine);
    }

    // Trace.
    final trace = Paint()
      ..color = const Color(0xFF6BE675)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final mid = size.height * 0.55;
    final amp = size.height * 0.32;
    for (var i = 0; i < samples.length; i++) {
      final x = i / samples.length * size.width;
      final y = mid - samples[i] * amp;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, trace);
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.samples != samples;
}
