import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_ui/synapse_ui.dart';

import 'app_providers.dart';

/// Shows the shared [OfflineBanner] when the app is offline (prompt 23/30 §3).
class NetworkBanner extends ConsumerWidget {
  const NetworkBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(networkOnlineProvider);
    if (online) return const SizedBox.shrink();
    return const OfflineBanner();
  }
}
