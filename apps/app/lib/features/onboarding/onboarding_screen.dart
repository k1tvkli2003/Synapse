import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/settings_provider.dart';
import '../../state/user_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  UserRole _role = UserRole.student;
  final Set<String> _interests = {};
  int _dailyGoal = 50;

  static const _goals = [
    ('Casual', 20),
    ('Regular', 50),
    ('Serious', 100),
    ('Intense', 150),
  ];

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      final settings = ref.read(settingsProvider.notifier);
      settings.setInterests(_interests.toList());
      settings.setDailyGoal(_dailyGoal);
      ref.read(userProvider.notifier).edit(role: _role);
      settings.completeOnboarding();
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: ContentBounds(
          maxWidth: 640,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step ? t.primary : t.surfaceHigh,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: t.motion.base,
                    child: _buildStep(t),
                  ),
                ),
                AppButton(
                  label: _step < 2 ? 'Continue' : 'Start learning',
                  expand: true,
                  onPressed: _step == 1 && _interests.isEmpty ? null : _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(SynapseTokens t) {
    switch (_step) {
      case 0:
        return SingleChildScrollView(
          key: const ValueKey(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who are you?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'We tailor your learning plan to your stage.',
                style: TextStyle(color: t.textMuted),
              ),
              const SizedBox(height: 20),
              ...UserRole.values.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => setState(() => _role = r),
                    accent: _role == r ? t.primary : null,
                    child: Row(
                      children: [
                        Icon(
                          _role == r
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _role == r ? t.primary : t.textFaint,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _roleLabel(r),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 1:
        return SingleChildScrollView(
          key: const ValueKey(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What do you want to focus on?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a few — all modules stay available.',
                style: TextStyle(color: t.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ModuleKey.values
                    .map(
                      (m) => AppChip(
                        label: m.title,
                        icon: ModuleVisuals.icon(m),
                        accent: Color(m.accentHex),
                        selected: _interests.contains(m.id),
                        onTap: () => setState(() {
                          _interests.contains(m.id)
                              ? _interests.remove(m.id)
                              : _interests.add(m.id);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      default:
        return SingleChildScrollView(
          key: const ValueKey(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set your daily goal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Consistency beats intensity.',
                style: TextStyle(color: t.textMuted),
              ),
              const SizedBox(height: 20),
              ..._goals.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => setState(() => _dailyGoal = g.$2),
                    accent: _dailyGoal == g.$2 ? t.primary : null,
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: t.primary),
                        const SizedBox(width: 12),
                        Text(
                          g.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${g.$2} XP / day',
                          style: TextStyle(color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  String _roleLabel(UserRole r) => switch (r) {
    UserRole.student => 'Medical student',
    UserRole.resident => 'Resident',
    UserRole.nurse => 'Nurse',
    UserRole.clinician => 'Clinician',
    UserRole.other => 'Other / curious',
  };
}
