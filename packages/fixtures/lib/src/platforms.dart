enum FixtureOperatingSystem { android, ios, windows, macos, linux, web }

enum FixturePointerKind { touch, mouse }

final class PlatformFixture {
  const PlatformFixture({
    required this.os,
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.pointer,
    this.reducedMotion = false,
    this.rtl = false,
  });

  final FixtureOperatingSystem os;
  final double width;
  final double height;
  final double pixelRatio;
  final FixturePointerKind pointer;
  final bool reducedMotion;
  final bool rtl;
}

abstract final class FixturePlatforms {
  static const all = [
    PlatformFixture(
      os: FixtureOperatingSystem.android,
      width: 360,
      height: 800,
      pixelRatio: 3,
      pointer: FixturePointerKind.touch,
    ),
    PlatformFixture(
      os: FixtureOperatingSystem.ios,
      width: 393,
      height: 852,
      pixelRatio: 3,
      pointer: FixturePointerKind.touch,
      rtl: true,
    ),
    PlatformFixture(
      os: FixtureOperatingSystem.windows,
      width: 1440,
      height: 900,
      pixelRatio: 1.25,
      pointer: FixturePointerKind.mouse,
    ),
    PlatformFixture(
      os: FixtureOperatingSystem.macos,
      width: 1512,
      height: 982,
      pixelRatio: 2,
      pointer: FixturePointerKind.mouse,
    ),
    PlatformFixture(
      os: FixtureOperatingSystem.linux,
      width: 1366,
      height: 768,
      pixelRatio: 1,
      pointer: FixturePointerKind.mouse,
      reducedMotion: true,
    ),
    PlatformFixture(
      os: FixtureOperatingSystem.web,
      width: 1024,
      height: 768,
      pixelRatio: 1,
      pointer: FixturePointerKind.mouse,
    ),
  ];
}
