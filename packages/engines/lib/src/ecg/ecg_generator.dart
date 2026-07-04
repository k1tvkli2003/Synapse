import 'dart:math' as math;

import 'package:synapse_core/synapse_core.dart';

/// Synthesises an ECG trace as normalised samples in roughly `[-1.5, 2.0]`
/// (prompt 14). A CustomPainter in the UI maps these to a canvas. Pure math →
/// the ECG module needs no image assets and works fully offline.
class EcgGenerator {
  const EcgGenerator._();

  /// Generate [sampleCount] samples (~[secondsPerScreen]s of trace).
  static List<double> generate(
    EcgGenParams params, {
    int sampleCount = 600,
    double secondsPerScreen = 4.0,
  }) {
    final rand = math.Random(params.rhythm.index * 31 + params.rateBpm);
    final out = List<double>.filled(sampleCount, 0);
    if (params.rhythm == EcgRhythm.asystole) {
      for (var i = 0; i < sampleCount; i++) {
        out[i] = (rand.nextDouble() - 0.5) * 0.02; // near-flat with tiny noise
      }
      return out;
    }
    if (params.rhythm == EcgRhythm.vfib) {
      var v = 0.0;
      for (var i = 0; i < sampleCount; i++) {
        v += (rand.nextDouble() - 0.5) * 0.6;
        v *= 0.86; // mean-revert
        out[i] = v + math.sin(i * 0.3) * 0.4 * rand.nextDouble();
      }
      return out;
    }

    final rate = params.rateBpm.clamp(20, 250);
    final beatSec = 60.0 / rate;
    final dt = secondsPerScreen / sampleCount;

    // Pre-compute beat onsets, allowing RR irregularity for AF.
    final onsets = <double>[];
    var tt = 0.0;
    while (tt < secondsPerScreen + beatSec) {
      onsets.add(tt);
      final jitter = params.rhythm == EcgRhythm.afib
          ? (rand.nextDouble() - 0.5) * beatSec * 0.6
          : 0.0;
      tt += beatSec + jitter;
    }

    for (var i = 0; i < sampleCount; i++) {
      final t = i * dt;
      // Nearest preceding beat onset.
      double phase = 1e9;
      for (final o in onsets) {
        if (t >= o && (t - o) < phase) phase = t - o;
      }
      out[i] = _beat(phase, beatSec, params) +
          (params.rhythm == EcgRhythm.afib ? _fibrillatoryBaseline(t) : 0.0) +
          (rand.nextDouble() - 0.5) * 0.012; // fine noise
    }
    return out;
  }

  static double _fibrillatoryBaseline(double t) =>
      math.sin(t * 35) * 0.04 + math.sin(t * 53) * 0.03;

  /// One PQRST complex evaluated at [phase] seconds into the beat.
  static double _beat(double phase, double beatSec, EcgGenParams p) {
    final r = p.rhythm;
    double y = 0;

    final wideQrs = r == EcgRhythm.vtach ||
        r == EcgRhythm.hyperkalemia ||
        p.qrsWidthMs > 120;

    // P wave — absent in AF / VT / VF.
    final hasP = r != EcgRhythm.afib && r != EcgRhythm.vtach && r != EcgRhythm.vfib;
    if (hasP) {
      y += _gauss(phase, beatSec * 0.18, 0.018) * 0.18;
    }

    // QRS complex centred ~28% into the beat.
    final qrsCenter = beatSec * 0.30;
    if (r == EcgRhythm.vtach) {
      // Wide, sinusoidal, large.
      y += math.sin((phase - qrsCenter) * 16) *
          1.2 *
          _gauss(phase, qrsCenter, 0.10);
    } else {
      final qWidth = wideQrs ? 0.022 : 0.010;
      y -= _gauss(phase, qrsCenter - 0.02, qWidth) * 0.10; // Q
      y += _gauss(phase, qrsCenter, qWidth) * (wideQrs ? 1.3 : 1.5); // R
      y -= _gauss(phase, qrsCenter + 0.025, qWidth) * 0.28; // S
    }

    // ST segment + T wave.
    final stLevel = r == EcgRhythm.stemi ? (0.25 + p.stElevation) : 0.0;
    final tCenter = beatSec * 0.55;
    if (phase > qrsCenter + 0.03 && phase < tCenter + 0.12) {
      y += stLevel;
    }
    // T wave — peaked & tall in hyperkalemia.
    final tAmp = r == EcgRhythm.hyperkalemia ? 0.55 + (p.potassium - 5).clamp(0, 4) * 0.08 : 0.22;
    final tWidth = r == EcgRhythm.hyperkalemia ? 0.022 : 0.045;
    y += _gauss(phase, tCenter, tWidth) * tAmp;

    return y;
  }

  static double _gauss(double x, double mean, double sd) {
    final d = (x - mean) / sd;
    return math.exp(-0.5 * d * d);
  }

  /// Maps a clinical case rhythm to default generator params (rate, ST, K⁺).
  static EcgGenParams paramsForRhythm(EcgRhythm rhythm) => switch (rhythm) {
        EcgRhythm.sinus => const EcgGenParams(rateBpm: 72),
        EcgRhythm.tachycardia => const EcgGenParams(rateBpm: 140, rhythm: EcgRhythm.tachycardia),
        EcgRhythm.bradycardia => const EcgGenParams(rateBpm: 42, rhythm: EcgRhythm.bradycardia),
        EcgRhythm.afib => const EcgGenParams(rateBpm: 110, rhythm: EcgRhythm.afib),
        EcgRhythm.flutter => const EcgGenParams(rateBpm: 150, rhythm: EcgRhythm.flutter),
        EcgRhythm.vtach => const EcgGenParams(rateBpm: 180, rhythm: EcgRhythm.vtach, qrsWidthMs: 160),
        EcgRhythm.vfib => const EcgGenParams(rateBpm: 300, rhythm: EcgRhythm.vfib),
        EcgRhythm.stemi => const EcgGenParams(rateBpm: 88, rhythm: EcgRhythm.stemi, stElevation: 0.25),
        EcgRhythm.hyperkalemia => const EcgGenParams(rateBpm: 80, rhythm: EcgRhythm.hyperkalemia, potassium: 7.2, qrsWidthMs: 140),
        EcgRhythm.heartBlock => const EcgGenParams(rateBpm: 40, rhythm: EcgRhythm.heartBlock),
        EcgRhythm.asystole => const EcgGenParams(rateBpm: 20, rhythm: EcgRhythm.asystole),
      };
}
