import 'dart:math';

/// Randomness port. Domain code must receive this dependency explicitly.
abstract interface class RandomSource {
  int nextInt(int max);

  double nextDouble();
}

final class SecureRandomSource implements RandomSource {
  SecureRandomSource() : _random = Random.secure();

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();
}

/// Seeded adapter for reproducible simulations and tests.
final class SeededRandomSource implements RandomSource {
  SeededRandomSource(int seed) : _random = Random(seed);

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();
}
