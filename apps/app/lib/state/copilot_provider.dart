import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';

import 'app_providers.dart';

class CopilotMessage {
  CopilotMessage({required this.role, required this.text, this.citations = const [], this.suggestions = const []})
      : id = DateTime.now().microsecondsSinceEpoch;
  final int id;
  final String role; // 'user' | 'assistant'
  final String text;
  final List<Concept> citations;
  final List<LearnItem> suggestions;
  bool get isUser => role == 'user';
}

/// Copilot conversation state (prompt 10). With no AI gateway configured it runs
/// in **grounded** mode: answers are drawn from the local knowledge base and
/// always cite their concepts — never an ungrounded guess (prompt 51).
class CopilotNotifier extends Notifier<List<CopilotMessage>> {
  @override
  List<CopilotMessage> build() => [
        CopilotMessage(
          role: 'assistant',
          text: "Hi! I'm Copilot, your study companion. Ask me about any concept — "
              "I'll explain it and point you to drills, cards and cases. "
              "For educational use only, not clinical advice.",
        ),
      ];

  /// Optional context Copilot was opened with (the current screen's concept).
  String? screenContext;

  void setContext(String? ctx) => screenContext = ctx;

  void send(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    state = [...state, CopilotMessage(role: 'user', text: q)];
    state = [...state, _answer(q)];
  }

  void clear() => state = build();

  CopilotMessage _answer(String q) {
    final repo = ref.read(repositoryProvider);
    final results = repo.search(q);
    if (results.concepts.isEmpty && results.items.isEmpty) {
      return CopilotMessage(
        role: 'assistant',
        text: "I don't have a grounded answer for that in the Synapse knowledge base yet. "
            "Try a concept like 'hyperkalemia', 'anion gap', 'atrial fibrillation' or 'MRSA'. "
            "I only answer from sourced content — I won't guess on clinical matters.",
      );
    }
    final concept = results.concepts.isNotEmpty ? results.concepts.first : null;
    final buffer = StringBuffer();
    if (concept != null) {
      buffer.writeln('**${concept.name}** — ${concept.domain.label}');
      if (concept.summary != null) buffer.writeln('\n${concept.summary}');
      if (concept.links.isNotEmpty) {
        final related = concept.links
            .map((l) => repo.concept(l.to)?.name)
            .whereType<String>()
            .take(3)
            .join(', ');
        if (related.isNotEmpty) buffer.writeln('\nRelated: $related.');
      }
    } else {
      buffer.writeln("Here's what I found across your modules:");
    }
    final items = results.items.take(4).toList();
    return CopilotMessage(
      role: 'assistant',
      text: buffer.toString().trim(),
      citations: [?concept],
      suggestions: items,
    );
  }
}

final copilotProvider =
    NotifierProvider<CopilotNotifier, List<CopilotMessage>>(CopilotNotifier.new);
