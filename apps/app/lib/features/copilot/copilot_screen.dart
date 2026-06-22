import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/copilot_provider.dart';

const _copilotAccent = Color(0xFFB794F6);

/// The global, grounded Copilot chat (prompt 10). Answers cite concepts and
/// link to drills/cards/cases — it never guesses on clinical matters (prompt 51).
class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key});
  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(copilotProvider.notifier).send(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(copilotProvider);

    return ModuleScaffold(
      title: 'Copilot',
      subtitle: 'Grounded AI tutor',
      accent: _copilotAccent,
      padded: false,
      actions: [
        AppIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'New chat',
          onPressed: () => ref.read(copilotProvider.notifier).clear(),
        ),
      ],
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DisclaimerBanner(compact: true),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: messages.length,
              itemBuilder: (context, i) => _Bubble(message: messages[i]),
            ),
          ),
          _Composer(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final CopilotMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mine = message.isUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? _copilotAccent : t.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine ? null : Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? const Color(0xFF1A0F2E) : t.text,
                height: 1.5,
              ),
            ),
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.citations
                    .map((c) => AppChip(
                          label: c.name,
                          icon: Icons.menu_book_rounded,
                          accent: _copilotAccent,
                          onTap: () => context.push(Routes.concept(c.id)),
                        ))
                    .toList(),
              ),
            ],
            if (message.suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...message.suggestions.map((s) => InkWell(
                    onTap: () => context.push(s.route),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(ModuleVisuals.icon(s.module), size: 16, color: Color(s.module.accentHex)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.title, style: TextStyle(color: t.text, fontSize: 13))),
                          const Icon(Icons.arrow_outward_rounded, size: 14),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 12),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Ask about a concept…',
                filled: true,
                fillColor: t.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: _copilotAccent, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF1A0F2E)),
            ),
          ),
        ],
      ),
    );
  }
}
