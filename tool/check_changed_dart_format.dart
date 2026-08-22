import 'dart:io';

Future<void> main() async {
  final root = await _repositoryRoot();
  final paths = <String>{
    ...await _gitPaths(root, [
      'diff',
      '--name-only',
      '--diff-filter=ACMR',
      '-z',
      'HEAD',
      '--',
      '*.dart',
    ]),
    ...await _gitPaths(root, [
      'diff',
      '--cached',
      '--name-only',
      '--diff-filter=ACMR',
      '-z',
      '--',
      '*.dart',
    ]),
    ...await _gitPaths(root, [
      'ls-files',
      '--others',
      '--exclude-standard',
      '-z',
      '--',
      '*.dart',
    ]),
  };

  final files =
      paths
          .where((path) => !path.endsWith('.g.dart'))
          .where((path) => !path.endsWith('.freezed.dart'))
          .where((path) => File(_absolute(root, path)).existsSync())
          .toList(growable: false)
        ..sort();

  if (files.isEmpty) {
    stdout.writeln('Changed-Dart format gate PASS: no changed Dart files.');
    return;
  }

  for (var offset = 0; offset < files.length; offset += 50) {
    final end = (offset + 50).clamp(0, files.length);
    final chunk = files.sublist(offset, end);
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['format', '--output=none', '--set-exit-if-changed', ...chunk],
      workingDirectory: root,
      mode: ProcessStartMode.inheritStdio,
    );
    final result = await process.exitCode;
    if (result != 0) {
      stderr.writeln(
        'Changed-Dart format gate FAILED. Run `dart format` on the files '
        'listed above.',
      );
      exitCode = result;
      return;
    }
  }

  stdout.writeln(
    'Changed-Dart format gate PASS: ${files.length} changed files checked.',
  );
}

Future<String> _repositoryRoot() async {
  final result = await Process.run('git', [
    'rev-parse',
    '--show-toplevel',
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw StateError('The format gate must run inside a Git repository.');
  }
  return (result.stdout as String).trim();
}

Future<List<String>> _gitPaths(String root, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: root,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw ProcessException('git', arguments, 'Git path query failed.');
  }
  return (result.stdout as String)
      .split('\u0000')
      .where((path) => path.isNotEmpty)
      .toList(growable: false);
}

String _absolute(String root, String relativePath) =>
    '$root${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
