import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/audio_provider.dart';

final _accent = Color(ModuleKey.orLab.accentHex);

class OrLabHomeScreen extends ConsumerWidget {
  const OrLabHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dramas = ref.watch(repositoryProvider).dramas;
    return ModuleScaffold(
      title: 'OR Lab',
      subtitle: ModuleKey.orLab.tagline,
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: dramas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = dramas[i];
          return AppCard(
            accent: _accent,
            onTap: () => context.push(Routes.drama(d.id)),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.medical_services_rounded, color: _accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title, style: Theme.of(context).textTheme.titleMedium),
                      Text('${d.surgery ?? ''} · ${(d.durationSec / 60).toStringAsFixed(0)} min · ${d.cues.length} cues',
                          style: TextStyle(color: t.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_fill_rounded, color: _accent),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DramaPlayerScreen extends ConsumerWidget {
  const DramaPlayerScreen({super.key, required this.dramaId});
  final String dramaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final d = repo.dramas.firstWhere((x) => x.id == dramaId, orElse: () => repo.dramas.first);
    final audio = ref.watch(audioProvider);
    final isThis = audio.sourceId == d.id;
    final pos = isThis ? audio.position.inSeconds.toDouble() : 0.0;

    return ModuleScaffold(
      title: d.title,
      subtitle: d.surgery,
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          AppCard(
            feature: true,
            accent: _accent,
            child: Column(
              children: [
                Waveform(seed: d.id.hashCode, progress: isThis && d.durationSec > 0 ? pos / d.durationSec : 0, color: _accent),
                const SizedBox(height: 14),
                AppButton(
                  label: isThis && audio.isPlaying ? 'Pause' : 'Play drama',
                  icon: isThis && audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  accent: _accent,
                  expand: true,
                  onPressed: () {
                    if (isThis) {
                      ref.read(audioProvider.notifier).toggle();
                    } else {
                      ref.read(audioProvider.notifier).load(
                            sourceId: d.id,
                            title: d.title,
                            subtitle: d.surgery,
                            duration: Duration(seconds: d.durationSec.round()),
                            accentHex: _accent.toARGB32(),
                          );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Synced timeline'),
          ...d.cues.map((cue) {
            final active = isThis && pos >= cue.atSec && pos < cue.atSec + 25;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active ? _accent.withValues(alpha: 0.14) : t.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? _accent : t.border),
              ),
              child: Row(
                children: [
                  Icon(_cueIcon(cue.kind), color: active ? _accent : t.textMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cue.label, style: Theme.of(context).textTheme.titleSmall),
                        if (cue.detail != null) Text(cue.detail!, style: TextStyle(color: t.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('${cue.atSec.round()}s', style: TextStyle(color: t.textFaint, fontSize: 11)),
                ],
              ),
            );
          }),
          if (d.transcript != null) ...[
            const SizedBox(height: 16),
            AppCard(child: Text(d.transcript!, style: TextStyle(color: t.textMuted, height: 1.6))),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  IconData _cueIcon(CueKind k) => switch (k) {
        CueKind.keyTerm => Icons.menu_book_rounded,
        CueKind.instrument => Icons.build_rounded,
        CueKind.step => Icons.flag_rounded,
      };
}
