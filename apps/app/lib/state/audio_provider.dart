import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the single shared [AudioPlayerBar] (prompt 30 §2). With no audio
/// assets bundled, playback is simulated by a ticking clock so the shared
/// transport UI, scrubbing and "now playing" persistence all work end-to-end
/// across Sounds, OR Lab and Rounds.
class AudioState {
  const AudioState({
    this.title,
    this.subtitle,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.accentHex,
    this.sourceId,
  });

  final String? title;
  final String? subtitle;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final int? accentHex;
  final String? sourceId;

  bool get hasMedia => title != null && duration > Duration.zero;

  AudioState copyWith({
    String? title,
    String? subtitle,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    int? accentHex,
    String? sourceId,
  }) {
    return AudioState(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      accentHex: accentHex ?? this.accentHex,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}

class AudioNotifier extends Notifier<AudioState> {
  Timer? _timer;

  @override
  AudioState build() {
    ref.onDispose(() => _timer?.cancel());
    return const AudioState();
  }

  void load({
    required String sourceId,
    required String title,
    String? subtitle,
    required Duration duration,
    int? accentHex,
    bool autoplay = true,
  }) {
    state = AudioState(
      sourceId: sourceId,
      title: title,
      subtitle: subtitle,
      duration: duration,
      accentHex: accentHex,
      position: Duration.zero,
      isPlaying: false,
    );
    if (autoplay) play();
  }

  void play() {
    if (!state.hasMedia) return;
    state = state.copyWith(isPlaying: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final next = state.position + const Duration(milliseconds: 250);
      if (next >= state.duration) {
        state = state.copyWith(position: state.duration, isPlaying: false);
        _timer?.cancel();
      } else {
        state = state.copyWith(position: next);
      }
    });
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  void toggle() => state.isPlaying ? pause() : play();

  void seek(Duration to) {
    state = state.copyWith(position: to.isNegative ? Duration.zero : to);
  }

  void stop() {
    _timer?.cancel();
    state = const AudioState();
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);
