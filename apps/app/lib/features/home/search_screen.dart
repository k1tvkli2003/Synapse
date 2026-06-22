import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';

/// One global search across concepts + every module's items (prompt 36).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final results = repo.search(_query);

    return ModuleScaffold(
      title: 'Search',
      padded: false,
      leading: const SizedBox(width: 8),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SearchField(
              controller: _controller,
              autofocus: true,
              hint: 'Search concepts, terms, ECGs, mnemonics…',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? _Suggestions(onTap: (q) {
                    _controller.text = q;
                    setState(() => _query = q);
                  })
                : results.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results',
                        message: 'Try "hyperkalemia", "anion gap" or "MRSA".',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        children: [
                          if (results.concepts.isNotEmpty) ...[
                            const SectionHeader(title: 'Concepts'),
                            ...results.concepts.map((c) => ListRow(
                                  title: c.name,
                                  subtitle: c.domain.label,
                                  leadingIcon: Icons.hub_rounded,
                                  onTap: () => context.push(Routes.concept(c.id)),
                                )),
                            const SizedBox(height: 12),
                          ],
                          if (results.items.isNotEmpty) ...[
                            SectionHeader(title: 'In your modules (${results.items.length})'),
                            ...results.items.map((i) => ListRow(
                                  title: i.title,
                                  subtitle: '${i.module.title}${i.subtitle != null ? ' · ${i.subtitle}' : ''}',
                                  leadingIcon: ModuleVisuals.icon(i.module),
                                  accent: Color(i.module.accentHex),
                                  onTap: () => context.push(i.route),
                                )),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});
  final ValueChanged<String> onTap;
  static const _chips = ['Hyperkalemia', 'STEMI', 'Anion gap', 'MRSA', 'Anemia', 'Atrial fibrillation'];
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Try searching', style: TextStyle(color: t.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _chips.map((c) => AppChip(label: c, onTap: () => onTap(c))).toList(),
          ),
        ],
      ),
    );
  }
}
