import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../state/cloud_sync_provider.dart';
import '../../state/game_provider.dart';
import '../../state/user_provider.dart';

/// Edit the user profile (prompt 06 / 42 §1).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _specialty;
  late final TextEditingController _bio;
  UserRole _role = UserRole.student;

  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider);
    _name = TextEditingController(text: u.displayName);
    _specialty = TextEditingController(text: u.specialty ?? '');
    _bio = TextEditingController(text: u.bio ?? '');
    _role = u.role;
  }

  @override
  void dispose() { _name.dispose(); _specialty.dispose(); _bio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'Edit profile',
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Center(child: AppAvatar(name: _name.text.isEmpty ? '?' : _name.text, radius: 40)),
        const SizedBox(height: 20),
        AppTextField(controller: _name, label: 'Display name'),
        const SizedBox(height: 12),
        AppTextField(controller: _specialty, label: 'Specialty', hint: 'e.g. Internal Medicine'),
        const SizedBox(height: 12),
        AppTextField(controller: _bio, label: 'Bio', maxLines: 3),
        const SizedBox(height: 12),
        Text('Role', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in UserRole.values)
            AppChip(label: r.name, selected: _role == r, onTap: () => setState(() => _role = r)),
        ]),
        const SizedBox(height: 20),
        AppButton(label: 'Save', expand: true, onPressed: () {
          ref.read(userProvider.notifier).edit(
            displayName: _name.text.trim(),
            specialty: _specialty.text.trim().isEmpty ? null : _specialty.text.trim(),
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            role: _role,
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), behavior: SnackBarBehavior.floating));
          Navigator.of(context).maybePop();
        }),
        const _CloudSyncSection(),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Cross-device account sync (prompt 05/42) — email one-time-code sign-in.
/// Invisible when no backend is configured; offline-first stays the default.
class _CloudSyncSection extends ConsumerStatefulWidget {
  const _CloudSyncSection();
  @override
  ConsumerState<_CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<_CloudSyncSection> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(cloudSyncControllerProvider);
    if (sync.phase == CloudSyncPhase.offline) return const SizedBox.shrink();
    final t = context.tokens;
    final notifier = ref.read(cloudSyncControllerProvider.notifier);

    late final Widget body;
    switch (sync.phase) {
      case CloudSyncPhase.offline:
        body = const SizedBox.shrink();
      case CloudSyncPhase.signedOut:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sign in with email to sync your progress across devices.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5)),
          const SizedBox(height: 12),
          AppTextField(controller: _email, label: 'Email', hint: 'you@example.com'),
          const SizedBox(height: 12),
          AppButton(
            label: 'Send code',
            expand: true,
            onPressed: () {
              final email = _email.text.trim();
              if (email.contains('@')) notifier.sendCode(email);
            },
          ),
        ]);
      case CloudSyncPhase.codeSent:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('We sent a 6-digit code to ${sync.email}.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5)),
          const SizedBox(height: 12),
          AppTextField(controller: _code, label: 'Code', hint: '123456'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: AppButton(
                label: 'Verify',
                expand: true,
                onPressed: () {
                  final email = sync.email;
                  if (email != null && _code.text.trim().isNotEmpty) {
                    notifier.confirmCode(email, _code.text.trim());
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: notifier.signOut, child: const Text('Change email')),
          ]),
        ]);
      case CloudSyncPhase.syncing:
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Syncing…'),
          ]),
        );
      case CloudSyncPhase.signedIn:
        body = Row(children: [
          Icon(Icons.cloud_done_rounded, color: t.success, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Synced as ${sync.email}', style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: notifier.signOut, child: const Text('Sign out')),
        ]);
      case CloudSyncPhase.error:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sync.message ?? 'Something went wrong.', style: TextStyle(color: t.danger, fontSize: 12.5)),
          const SizedBox(height: 8),
          AppButton(label: 'Try again', expand: true, onPressed: notifier.signOut),
        ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const SectionHeader(title: 'Cloud sync'),
      const SizedBox(height: 8),
      AppCard(child: body),
    ]);
  }
}

/// Privacy & data center (prompt 42 §2/§3): export, delete, visibility.
class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});
  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _publicProfile = true;
  bool _presence = true;
  bool _buddyAvailable = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Privacy & data',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const SectionHeader(title: 'Visibility'),
          AppCard(child: Column(children: [
            AppSwitchTile(title: 'Public profile', subtitle: 'Show /u/handle page', icon: Icons.public_rounded, value: _publicProfile, onChanged: (v) => setState(() => _publicProfile = v)),
            AppSwitchTile(title: 'Show presence', subtitle: 'Let others see when you are online', icon: Icons.circle_rounded, value: _presence, onChanged: (v) => setState(() => _presence = v)),
            AppSwitchTile(title: 'Available for study buddies', icon: Icons.group_rounded, value: _buddyAvailable, onChanged: (v) => setState(() => _buddyAvailable = v)),
          ])),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Your data'),
          AppCard(child: Column(children: [
            ListRow(
              title: 'Export my data',
              subtitle: 'Download all your data (machine-readable)',
              leadingIcon: Icons.download_rounded,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing export — you will be notified when ready'), behavior: SnackBarBehavior.floating)),
            ),
            ListRow(
              title: 'Delete my account',
              subtitle: 'Permanently erase all data',
              leadingIcon: Icons.delete_forever_rounded,
              accent: t.danger,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _confirmDelete(context),
            ),
          ])),
          const SizedBox(height: 16),
          AppCard(color: t.surfaceAlt, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.shield_rounded, size: 16, color: t.success), const SizedBox(width: 8), Text('Our promises', style: Theme.of(context).textTheme.titleSmall)]),
            const SizedBox(height: 8),
            _promise(t, 'No PHI is persisted by default — lab inputs are transient.'),
            _promise(t, 'AI keys are server-only; AI never sees identifying data.'),
            _promise(t, 'Encryption in transit; row-level security on every record.'),
            _promise(t, 'A HIPAA-readiness posture is documented for future clinical features.'),
          ])),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _promise(SynapseTokens t, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.check, size: 12, color: t.success)),
          Expanded(child: Text(s, style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
        ]),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message: 'This permanently erases all your data. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion requested'), behavior: SnackBarBehavior.floating));
    }
  }
}

/// Redeem a promo / institutional code (prompt 40 §4).
class RedeemScreen extends ConsumerStatefulWidget {
  const RedeemScreen({super.key});
  @override
  ConsumerState<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends ConsumerState<RedeemScreen> {
  final _c = TextEditingController();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Redeem a code',
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Text('Enter a promo or institutional code to unlock gems or Pro.', style: TextStyle(color: t.textMuted)),
        const SizedBox(height: 16),
        AppTextField(controller: _c, label: 'Code', hint: 'e.g. SYNAPSE-GEMS'),
        const SizedBox(height: 16),
        AppButton(label: 'Redeem', expand: true, onPressed: () {
          final code = _c.text.trim().toUpperCase();
          if (code.contains('GEMS')) {
            ref.read(gameProvider.notifier).grantGems(250);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redeemed: +250 gems'), behavior: SnackBarBehavior.floating));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid or expired code'), behavior: SnackBarBehavior.floating));
          }
          _c.clear();
        }),
        const SizedBox(height: 30),
      ]),
    );
  }
}

/// Versioned legal / governance documents (prompt 42 §3 / 50).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (title, body) = _content(doc);
    return ModuleScaffold(
      title: title,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        const DisclaimerBanner(),
        const SizedBox(height: 16),
        for (final para in body) ...[
          Text(para, style: TextStyle(color: t.text, height: 1.55)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  (String, List<String>) _content(String doc) => switch (doc) {
        'governance' => ('Clinical governance', [
            'Every clinical fact in Synapse is sourced, reviewed and dated. Content moves through a two-tier editorial workflow: an author drafts it, a clinical reviewer approves it, and high-risk content (drug dosing, lab rule-sets, guidelines) requires a senior reviewer.',
            'Each reference page shows its sources, last-reviewed date and evidence level, and a "Report an error" button routes issues to a triage queue.',
            'AI-generated content is never auto-published — it enters a draft state and must pass human review with candidate citations attached.',
            'Lab rule-sets are versioned with a full audit trail so any interpretation can be traced to the exact rules that produced it.',
          ]),
        'privacy' => ('Privacy policy', [
            'Synapse is offline-first and stores your progress locally by default. No protected health information (PHI) is persisted by default; lab calculator inputs are transient.',
            'Analytics are strictly opt-in. AI gateway keys are server-only and AI never receives identifying data.',
            'You can export or delete all of your data at any time from Settings → Privacy & data.',
          ]),
        _ => ('Terms of use', [
            'Synapse is for educational training only and is not a medical device. It must not be used for real clinical decision making.',
            'Content is provided "as is" for learning. Always verify against primary sources and local guidelines.',
            'By using Synapse you agree to use it responsibly and in accordance with your institution\'s policies.',
            'Open-source licenses for bundled components are available on request.',
          ]),
      };
}
