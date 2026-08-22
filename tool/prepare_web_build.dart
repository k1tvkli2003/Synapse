import 'dart:io';

/// Removes only reproducible Flutter Web compiler state.
///
/// `flutter clean` also removes native platform and plugin metadata. On a
/// Windows host without symlink privileges that metadata cannot be restored,
/// even though a Web build itself is supported. Keeping this cleanup narrow
/// makes repeated release builds deterministic without mutating native setup.
Future<void> main() async {
  final repositoryPath = Directory.current.absolute.resolveSymbolicLinksSync();
  final separator = Platform.pathSeparator;
  final appPath = Directory(
    '$repositoryPath${separator}apps${separator}app',
  ).resolveSymbolicLinksSync();
  final targets = <Directory>[
    Directory('$appPath${separator}build${separator}web'),
    Directory('$appPath$separator.dart_tool${separator}flutter_build'),
  ];

  for (final target in targets) {
    final resolved = target.existsSync()
        ? target.resolveSymbolicLinksSync()
        : target.absolute.path;
    _requireGeneratedChild(appPath, resolved);
    if (target.existsSync()) await target.delete(recursive: true);
    stdout.writeln('Prepared clean Web target: $resolved');
  }
}

void _requireGeneratedChild(String appPath, String targetPath) {
  final normalize = Platform.isWindows
      ? (String value) => value.toLowerCase()
      : (String value) => value;
  final root = normalize(appPath);
  final target = normalize(targetPath);
  final prefix = '$root${Platform.pathSeparator}';
  if (target == root || !target.startsWith(prefix)) {
    throw StateError('Refusing to clean a path outside the Flutter app.');
  }
}
