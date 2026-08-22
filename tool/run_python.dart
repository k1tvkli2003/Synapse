import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart run tool/run_python.dart <script> [arguments]');
    exitCode = 64;
    return;
  }

  final python = await _findPython();
  if (python == null) {
    stderr.writeln(
      'Python 3 was not found. Install it or set SYNAPSE_PYTHON to the '
      'absolute interpreter path.',
    );
    exitCode = 69;
    return;
  }

  final process = await Process.start(
    python.executable,
    [...python.prefixArguments, ...arguments],
    mode: ProcessStartMode.inheritStdio,
    runInShell: python.runInShell,
  );
  exitCode = await process.exitCode;
}

Future<_Python?> _findPython() async {
  final configured = Platform.environment['SYNAPSE_PYTHON'];
  final candidates = <_Python>[
    if (configured != null && configured.trim().isNotEmpty)
      _Python(configured.trim()),
    if (Platform.isWindows) ...[
      const _Python('python', runInShell: true),
      const _Python('py', prefixArguments: ['-3'], runInShell: true),
      const _Python('python3', runInShell: true),
    ] else ...[
      const _Python('python3'),
      const _Python('python'),
    ],
  ];

  for (final candidate in candidates) {
    try {
      final result = await Process.run(candidate.executable, [
        ...candidate.prefixArguments,
        '--version',
      ], runInShell: candidate.runInShell);
      final version = '${result.stdout}${result.stderr}';
      if (result.exitCode == 0 && version.startsWith('Python 3.')) {
        return candidate;
      }
    } on ProcessException {
      // Try the next standard interpreter name.
    }
  }
  return null;
}

final class _Python {
  const _Python(
    this.executable, {
    this.prefixArguments = const [],
    this.runInShell = false,
  });

  final String executable;
  final List<String> prefixArguments;
  final bool runInShell;
}
