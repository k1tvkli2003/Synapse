import 'package:flutter/material.dart';

import 'academy_study_workspace_screen.dart' deferred as workspace;

/// Route boundary for the non-initial Deep Study workspace.
///
/// Web builds keep the feature's rich document renderer outside the initial
/// JavaScript payload. Native builds preserve the exact same route and screen
/// contract; loading the deferred library is effectively local there.
class AcademyStudyWorkspaceLoader extends StatefulWidget {
  const AcademyStudyWorkspaceLoader({super.key, required this.nodeId});

  final String nodeId;

  @override
  State<AcademyStudyWorkspaceLoader> createState() =>
      _AcademyStudyWorkspaceLoaderState();
}

class _AcademyStudyWorkspaceLoaderState
    extends State<AcademyStudyWorkspaceLoader> {
  late Future<void> _workspaceLibrary;

  @override
  void initState() {
    super.initState();
    _workspaceLibrary = workspace.loadLibrary();
  }

  void _retry() {
    setState(() {
      _workspaceLibrary = workspace.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _workspaceLibrary,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return workspace.AcademyStudyWorkspaceScreen(nodeId: widget.nodeId);
        }

        final isPersian = Localizations.localeOf(context).languageCode == 'fa';
        final failed = snapshot.hasError;
        final title = failed
            ? (isPersian ? 'فضای مطالعه باز نشد' : 'Deep Study did not open')
            : (isPersian
                  ? 'در حال باز کردن مطالعهٔ عمیق'
                  : 'Opening Deep Study');
        final body = failed
            ? (isPersian
                  ? 'اتصال را بررسی کنید و دوباره تلاش کنید.'
                  : 'Check your connection and try again.')
            : (isPersian
                  ? 'محیط مطالعهٔ این درس در حال آماده‌شدن است.'
                  : 'Preparing this lesson’s focused study space.');

        return Scaffold(
          backgroundColor: const Color(0xFF031329),
          body: SafeArea(
            child: Center(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: '$title. $body',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (failed)
                          const Icon(
                            Icons.sync_problem_rounded,
                            color: Color(0xFF71D8FF),
                            size: 42,
                          )
                        else
                          const SizedBox.square(
                            dimension: 42,
                            child: CircularProgressIndicator(
                              color: Color(0xFF27C3F3),
                              strokeWidth: 3,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFFF4F8FF),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFFA8BBDD),
                                height: 1.45,
                              ),
                        ),
                        if (failed) ...[
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              isPersian ? 'تلاش دوباره' : 'Try again',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
