import 'dart:math';

final _rng = Random.secure();

/// Cryptographically random key sent with every money-moving request so the
/// server can safely ignore duplicates (double taps, retries, flaky networks).
String newIdempotencyKey() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}
