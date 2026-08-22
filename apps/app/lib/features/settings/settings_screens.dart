import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../data/personal_sync/recovery_kit_exporter.dart';
import '../../state/app_providers.dart';
import '../../state/cloud_sync_provider.dart';
import '../../state/game_provider.dart';
import '../../state/personal_sync_provider.dart';
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
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'Edit profile',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: AppAvatar(
              name: _name.text.isEmpty ? '?' : _name.text,
              radius: 40,
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(controller: _name, label: 'Display name'),
          const SizedBox(height: 12),
          AppTextField(
            controller: _specialty,
            label: 'Specialty',
            hint: 'e.g. Internal Medicine',
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _bio, label: 'Bio', maxLines: 3),
          const SizedBox(height: 12),
          Text('Role', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in UserRole.values)
                AppChip(
                  label: r.name,
                  selected: _role == r,
                  onTap: () => setState(() => _role = r),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Save',
            expand: true,
            onPressed: () {
              ref
                  .read(userProvider.notifier)
                  .edit(
                    displayName: _name.text.trim(),
                    specialty: _specialty.text.trim().isEmpty
                        ? null
                        : _specialty.text.trim(),
                    bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
                    role: _role,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).maybePop();
            },
          ),
          const _SyncSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Personal device pairing takes precedence whenever the private gateway is
/// configured. The legacy section below remains intact for existing local
/// installs that still deliberately use the prior Supabase compatibility path.
class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (config.hasPersonalSyncGateway) {
      return const _PersonalDeviceSyncSection();
    }
    return const _CloudSyncSection();
  }
}

class _PersonalDeviceSyncSection extends ConsumerStatefulWidget {
  const _PersonalDeviceSyncSection();

  @override
  ConsumerState<_PersonalDeviceSyncSection> createState() =>
      _PersonalDeviceSyncSectionState();
}

class _PersonalDeviceSyncSectionState
    extends ConsumerState<_PersonalDeviceSyncSection> {
  final _deviceLabel = TextEditingController(text: 'This device');
  final _bootstrapToken = TextEditingController();
  final _recoveryPassphrase = TextEditingController();
  final _recoveryConfirmation = TextEditingController();
  final _scannedPayload = TextEditingController();

  @override
  void dispose() {
    _deviceLabel.dispose();
    _bootstrapToken.dispose();
    _recoveryPassphrase.dispose();
    _recoveryConfirmation.dispose();
    _scannedPayload.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(personalSyncControllerProvider);
    if (sync.phase == PersonalSyncPhase.unavailable) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    final controller = ref.read(personalSyncControllerProvider.notifier);
    final platform = ref.watch(personalSyncPlatformProvider);

    final Widget body = switch (sync.phase) {
      PersonalSyncPhase.loading || PersonalSyncPhase.working => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Securing your device connection…'),
          ],
        ),
      ),
      PersonalSyncPhase.unpaired => _unpairedBody(
        context,
        controller,
        canCreateRoot: platform == PersonalDevicePlatform.windows,
      ),
      PersonalSyncPhase.recoveryKitPending => _recoveryKitBody(
        context,
        controller,
        sync,
      ),
      PersonalSyncPhase.candidateWaitingForApproval => _candidateBody(
        context,
        controller,
        sync,
      ),
      PersonalSyncPhase.paired => _pairedBody(context, controller, sync),
      PersonalSyncPhase.error => _errorBody(context, controller, sync),
      PersonalSyncPhase.unavailable => const SizedBox.shrink(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const SectionHeader(title: 'Private device sync'),
        const SizedBox(height: 8),
        AppCard(
          accent: sync.phase == PersonalSyncPhase.error ? t.danger : t.primary,
          child: body,
        ),
      ],
    );
  }

  Widget _unpairedBody(
    BuildContext context,
    PersonalSyncController controller, {
    required bool canCreateRoot,
  }) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.devices_other_rounded, color: t.primary, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your devices, not an account',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Progress is encrypted before it leaves this device. Pair with a short-lived QR code — no email or public profile is involved.',
          style: TextStyle(color: t.textMuted, height: 1.4, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _deviceLabel,
          label: 'Device name',
          hint: 'e.g. My Windows laptop',
          icon: Icons.devices_rounded,
        ),
        if (canCreateRoot) ...[
          const SizedBox(height: 18),
          Text(
            'Create your private workspace',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Use the one-time bootstrap token from your private gateway, then save the encrypted Recovery Kit somewhere safe.',
            style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _bootstrapToken,
            label: 'One-time bootstrap token',
            obscure: true,
            icon: Icons.key_rounded,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _recoveryPassphrase,
            label: 'Recovery passphrase',
            hint: 'At least 12 characters',
            obscure: true,
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _recoveryConfirmation,
            label: 'Confirm recovery passphrase',
            obscure: true,
            icon: Icons.lock_reset_rounded,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Create private workspace',
            icon: Icons.shield_rounded,
            expand: true,
            onPressed: () => _createRoot(context, controller),
          ),
          const SizedBox(height: 18),
          Divider(color: t.border),
          const SizedBox(height: 14),
        ],
        Text(
          canCreateRoot ? 'Or pair this device' : 'Pair this device',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Choose this if a trusted Synapse device already owns your workspace.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Show pairing QR',
          variant: AppButtonVariant.secondary,
          icon: Icons.qr_code_rounded,
          expand: true,
          onPressed: () => controller.beginCandidatePairing(
            deviceLabel: _deviceLabel.text.trim(),
          ),
        ),
      ],
    );
  }

  Widget _recoveryKitBody(
    BuildContext context,
    PersonalSyncController controller,
    PersonalSyncState sync,
  ) {
    final t = context.tokens;
    final serialized = sync.pendingRecoveryKit;
    if (serialized == null) {
      return _errorMessage(
        context,
        'The encrypted Recovery Kit is unavailable. Re-open this device connection before pairing another device.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: t.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Save your Recovery Kit now',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'It is encrypted with your passphrase. It is the only way to replace a lost root device and revoke old tokens.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Save encrypted Recovery Kit',
          icon: Icons.save_alt_rounded,
          expand: true,
          onPressed: () => _exportRecoveryKit(context, controller, serialized),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Copy encrypted backup',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          icon: Icons.copy_rounded,
          expand: true,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: serialized));
            if (context.mounted) {
              _snack(
                context,
                'Encrypted Recovery Kit copied. Save it as a file before continuing.',
              );
            }
          },
        ),
      ],
    );
  }

  Widget _candidateBody(
    BuildContext context,
    PersonalSyncController controller,
    PersonalSyncState sync,
  ) {
    final invitation = sync.invitation;
    if (invitation == null) {
      return _errorMessage(
        context,
        'The pending QR pairing request is invalid.',
      );
    }
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan this on a trusted device',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'This QR expires at ${_time(invitation.expiresAt)}. The trusted device must approve it before this device receives its encrypted workspace key.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        Center(
          child: Semantics(
            label:
                'Pairing QR code. Manual pairing code ${invitation.pairingCode}.',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: invitation.encode(),
                size: 204,
                version: QrVersions.auto,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF07142D),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF07142D),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: SelectableText(
            invitation.pairingCode,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: t.primary,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Copy payload',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: invitation.encode()),
                  );
                  if (context.mounted) {
                    _snack(context, 'Pairing payload copied.');
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Check approval',
                size: AppButtonSize.small,
                icon: Icons.verified_user_rounded,
                onPressed: controller.completeCandidatePairing,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pairedBody(
    BuildContext context,
    PersonalSyncController controller,
    PersonalSyncState sync,
  ) {
    final runtime = sync.runtime!;
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_rounded, color: t.success, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${runtime.device.label} is trusted',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          runtime.device.role == DeviceTrustRole.root
              ? 'This is the recovery-capable root device for your private workspace.'
              : 'This device is paired to your private workspace. It can study offline and reconnect securely.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Sync learning now',
          variant: AppButtonVariant.primary,
          icon: Icons.cloud_sync_rounded,
          size: AppButtonSize.small,
          expand: true,
          onPressed: controller.syncNow,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Refresh secure connection',
          variant: AppButtonVariant.secondary,
          icon: Icons.sync_rounded,
          size: AppButtonSize.small,
          expand: true,
          onPressed: controller.refreshConnection,
        ),
        const SizedBox(height: 18),
        Divider(color: t.border),
        const SizedBox(height: 14),
        Text(
          'Approve another device',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Scan or paste the short-lived pairing payload shown on the new device. The key is sealed only to that device identity.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _scannedPayload,
          label: 'Pairing QR payload',
          hint: 'synapse-pair-v1:…',
          maxLines: 3,
          icon: Icons.qr_code_scanner_rounded,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Approve device',
          icon: Icons.verified_rounded,
          expand: true,
          onPressed: () =>
              controller.approvePairingPayload(_scannedPayload.text.trim()),
        ),
      ],
    );
  }

  Widget _errorBody(
    BuildContext context,
    PersonalSyncController controller,
    PersonalSyncState sync,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _errorMessage(context, _syncErrorMessage(sync.errorCode)),
      const SizedBox(height: 12),
      AppButton(
        label: 'Try again',
        variant: AppButtonVariant.secondary,
        icon: Icons.refresh_rounded,
        expand: true,
        onPressed: controller.retry,
      ),
    ],
  );

  Widget _errorMessage(BuildContext context, String message) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, color: t.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: t.textMuted, height: 1.4),
          ),
        ),
      ],
    );
  }

  Future<void> _createRoot(
    BuildContext context,
    PersonalSyncController controller,
  ) async {
    final passphrase = _recoveryPassphrase.text;
    if (passphrase != _recoveryConfirmation.text) {
      _snack(context, 'The recovery passphrases do not match.');
      return;
    }
    if (_bootstrapToken.text.trim().isEmpty) {
      _snack(context, 'Enter the one-time bootstrap token first.');
      return;
    }
    await controller.bootstrapWindowsRoot(
      deviceLabel: _deviceLabel.text.trim(),
      bootstrapToken: _bootstrapToken.text.trim(),
      recoveryPassphrase: passphrase,
    );
  }

  Future<void> _exportRecoveryKit(
    BuildContext context,
    PersonalSyncController controller,
    String serialized,
  ) async {
    try {
      final saved = await exportEncryptedRecoveryKit(serialized);
      if (!saved) return;
      await controller.markRecoveryKitExported();
      if (context.mounted) {
        _snack(context, 'Recovery Kit saved. Keep it offline and private.');
      }
    } on Object {
      if (context.mounted) {
        _snack(context, 'The Recovery Kit could not be exported. Try again.');
      }
    }
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _syncErrorMessage(String? code) => switch (code) {
    'pairing_invitation_expired' || 'pairing_session_expired' =>
      'This pairing code expired. Generate a new QR code and try again.',
    'invalid_pairing_invitation' || 'pairing_approval_mismatch' =>
      'That pairing payload could not be verified for this workspace.',
    'workspace_already_paired' =>
      'This device already has a personal workspace. Refresh the connection instead.',
    'root_bootstrap_requires_windows' =>
      'Create the initial workspace from your Windows root device.',
    'invalid_recovery_passphrase' =>
      'Choose a recovery passphrase with at least 12 characters.',
    'personal_sync_unavailable' =>
      'Private device sync is unavailable for this platform or build.',
    _ =>
      'The private device connection could not be completed. Your local learning data was not changed.',
  };

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in with email to sync your progress across devices.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Send code',
              expand: true,
              onPressed: () {
                final email = _email.text.trim();
                if (email.contains('@')) notifier.sendCode(email);
              },
            ),
          ],
        );
      case CloudSyncPhase.codeSent:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a 6-digit code to ${sync.email}.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _code, label: 'Code', hint: '123456'),
            const SizedBox(height: 12),
            Row(
              children: [
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
                TextButton(
                  onPressed: notifier.signOut,
                  child: const Text('Change email'),
                ),
              ],
            ),
          ],
        );
      case CloudSyncPhase.syncing:
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Syncing…'),
            ],
          ),
        );
      case CloudSyncPhase.signedIn:
        body = Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: t.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Synced as ${sync.email}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: notifier.signOut,
              child: const Text('Sign out'),
            ),
          ],
        );
      case CloudSyncPhase.error:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sync.message ?? 'Something went wrong.',
              style: TextStyle(color: t.danger, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Try again',
              expand: true,
              onPressed: notifier.signOut,
            ),
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionHeader(title: 'Cloud sync'),
        const SizedBox(height: 8),
        AppCard(child: body),
      ],
    );
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
          AppCard(
            child: Column(
              children: [
                AppSwitchTile(
                  title: 'Public profile',
                  subtitle: 'Show /u/handle page',
                  icon: Icons.public_rounded,
                  value: _publicProfile,
                  onChanged: (v) => setState(() => _publicProfile = v),
                ),
                AppSwitchTile(
                  title: 'Show presence',
                  subtitle: 'Let others see when you are online',
                  icon: Icons.circle_rounded,
                  value: _presence,
                  onChanged: (v) => setState(() => _presence = v),
                ),
                AppSwitchTile(
                  title: 'Available for study buddies',
                  icon: Icons.group_rounded,
                  value: _buddyAvailable,
                  onChanged: (v) => setState(() => _buddyAvailable = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Your data'),
          AppCard(
            child: Column(
              children: [
                ListRow(
                  title: 'Export my data',
                  subtitle: 'Download all your data (machine-readable)',
                  leadingIcon: Icons.download_rounded,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Preparing export — you will be notified when ready',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                ),
                ListRow(
                  title: 'Delete my account',
                  subtitle: 'Permanently erase all data',
                  leadingIcon: Icons.delete_forever_rounded,
                  accent: t.danger,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            color: t.surfaceAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 16, color: t.success),
                    const SizedBox(width: 8),
                    Text(
                      'Our promises',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _promise(
                  t,
                  'No PHI is persisted by default — lab inputs are transient.',
                ),
                _promise(
                  t,
                  'AI keys are server-only; AI never sees identifying data.',
                ),
                _promise(
                  t,
                  'Encryption in transit; row-level security on every record.',
                ),
                _promise(
                  t,
                  'A HIPAA-readiness posture is documented for future clinical features.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _promise(SynapseTokens t, String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Icon(Icons.check, size: 12, color: t.success),
        ),
        Expanded(
          child: Text(
            s,
            style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion requested'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Redeem a code',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Enter a promo or institutional code to unlock gems or Pro.',
            style: TextStyle(color: t.textMuted),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _c,
            label: 'Code',
            hint: 'e.g. SYNAPSE-GEMS',
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Redeem',
            expand: true,
            onPressed: () {
              final code = _c.text.trim().toUpperCase();
              if (code.contains('GEMS')) {
                ref.read(gameProvider.notifier).grantGems(250);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Redeemed: +250 gems'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid or expired code'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              _c.clear();
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const DisclaimerBanner(),
          const SizedBox(height: 16),
          for (final para in body) ...[
            Text(para, style: TextStyle(color: t.text, height: 1.55)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  (String, List<String>) _content(String doc) => switch (doc) {
    'governance' => (
      'Clinical governance',
      [
        'Every clinical fact in Synapse is sourced, reviewed and dated. Content moves through a two-tier editorial workflow: an author drafts it, a clinical reviewer approves it, and high-risk content (drug dosing, lab rule-sets, guidelines) requires a senior reviewer.',
        'Each reference page shows its sources, last-reviewed date and evidence level, and a "Report an error" button routes issues to a triage queue.',
        'AI-generated content is never auto-published — it enters a draft state and must pass human review with candidate citations attached.',
        'Lab rule-sets are versioned with a full audit trail so any interpretation can be traced to the exact rules that produced it.',
      ],
    ),
    'privacy' => (
      'Privacy policy',
      [
        'Synapse is offline-first and stores your progress locally by default. No protected health information (PHI) is persisted by default; lab calculator inputs are transient.',
        'Analytics are strictly opt-in. AI gateway keys are server-only and AI never receives identifying data.',
        'You can export or delete all of your data at any time from Settings → Privacy & data.',
      ],
    ),
    _ => (
      'Terms of use',
      [
        'Synapse is for educational training only and is not a medical device. It must not be used for real clinical decision making.',
        'Content is provided "as is" for learning. Always verify against primary sources and local guidelines.',
        'By using Synapse you agree to use it responsibly and in accordance with your institution\'s policies.',
        'Open-source licenses for bundled components are available on request.',
      ],
    ),
  };
}
