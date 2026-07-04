import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_ui/synapse_ui.dart';

const _accent = Color(0xFF6FD3E8);

/// Import / export & portability (prompt 44). Anki/CSV in, decks/reports out,
/// deep-link sharing — proving the architecture is open, not a silo.
class ImportExportScreen extends ConsumerWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    void toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

    return ModuleScaffold(
      title: 'Import & Export',
      subtitle: 'Synapse plays well with your tools',
      accent: _accent,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const SectionHeader(title: 'Import'),
        AppCard(child: Column(children: [
          ListRow(title: 'Anki deck (.apkg)', subtitle: 'Convert notes to Cards with concept auto-tagging', leadingIcon: Icons.style_rounded, accent: _accent, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => toast('Choose an .apkg file to import')),
          ListRow(title: 'CSV / JSON', subtitle: 'Terms, mnemonics, cases', leadingIcon: Icons.table_chart_rounded, accent: _accent, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => toast('Choose a CSV/JSON file to import')),
          ListRow(title: 'Media (images / audio)', subtitle: 'Upload to your content', leadingIcon: Icons.perm_media_rounded, accent: _accent, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => toast('Choose media to upload')),
        ])),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Export'),
        AppCard(child: Column(children: [
          ListRow(title: 'Export decks to Anki / CSV', leadingIcon: Icons.upload_file_rounded, accent: t.success, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => toast('Exporting your decks…')),
          ListRow(title: 'Study progress report (PDF)', leadingIcon: Icons.picture_as_pdf_rounded, accent: t.success, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => toast('Generating your progress report…')),
          ListRow(title: 'Full account data', subtitle: 'Machine-readable export', leadingIcon: Icons.download_rounded, accent: t.success, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => toast('Preparing your data export…')),
        ])),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Share & extend'),
        AppCard(child: Column(children: [
          ListRow(title: 'Deep-link sharing', subtitle: 'Share any concept, case or round with an OG preview', leadingIcon: Icons.link_rounded, accent: _accent),
          ListRow(title: 'Calendar (ICS)', subtitle: 'Sync study sessions to your calendar', leadingIcon: Icons.event_rounded, accent: _accent),
          ListRow(title: 'Plugin & content API', subtitle: 'A documented contract for new modules & importers', leadingIcon: Icons.extension_rounded, accent: _accent),
        ])),
        const SizedBox(height: 12),
        AppCard(color: t.surfaceAlt, child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: t.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text('A new module = implement the module contract + register routes + LearnItems. The architecture is extensible by design.', style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }
}
