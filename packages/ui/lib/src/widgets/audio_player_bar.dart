import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The single audio UI for the whole app (prompt 30 §2), shared by Sounds, OR
/// Lab and Rounds. It is a *controlled* widget — playback state is owned by a
/// provider so it can persist across navigation.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    this.onSeek,
    this.subtitle,
    this.accent,
    this.onClose,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final Color? accent;
  final VoidCallback? onClose;
  final bool dense;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    final total = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final value = (position.inMilliseconds / total).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.fromLTRB(12, dense ? 6 : 10, 12, dense ? 6 : 10),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _PlayButton(isPlaying: isPlaying, color: a, onTap: onPlayPause),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textMuted, size: 18),
                  onPressed: onClose,
                ),
            ],
          ),
          SizedBox(height: dense ? 4 : 8),
          Row(
            children: [
              Text(_fmt(position),
                  style: TextStyle(color: t.textMuted, fontSize: 11, fontFeatures: const [FontFeature.tabularFigures()])),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: a,
                    inactiveTrackColor: t.surfaceAlt,
                    thumbColor: a,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: onSeek == null
                        ? null
                        : (v) => onSeek!(Duration(milliseconds: (v * total).round())),
                  ),
                ),
              ),
              Text(_fmt(duration),
                  style: TextStyle(color: t.textMuted, fontSize: 11, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isPlaying, required this.color, required this.onTap});
  final bool isPlaying;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: t.glow(color, opacity: 0.3, blur: 14),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: t.isDark ? const Color(0xFF080B1C) : Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

/// A static/animated waveform visualisation used by the audio modules.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.seed,
    this.progress = 0,
    this.color,
    this.height = 56,
    this.bars = 48,
  });

  final int seed;
  final double progress;
  final Color? color;
  final double height;
  final int bars;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(
          seed: seed,
          progress: progress,
          color: color ?? t.primary,
          track: t.surfaceHigh,
          bars: bars,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.seed,
    required this.progress,
    required this.color,
    required this.track,
    required this.bars,
  });
  final int seed;
  final double progress;
  final Color color;
  final Color track;
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    const gap = 3.0;
    final barW = (size.width - gap * (bars - 1)) / bars;
    final mid = size.height / 2;
    for (var i = 0; i < bars; i++) {
      final h = (rand.nextDouble() * 0.7 + 0.15) * size.height;
      final x = i * (barW + gap);
      final played = (i / bars) <= progress;
      final paint = Paint()
        ..color = played ? color : track
        ..strokeWidth = barW
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x + barW / 2, mid - h / 2), Offset(x + barW / 2, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.progress != progress || old.seed != seed;
}
