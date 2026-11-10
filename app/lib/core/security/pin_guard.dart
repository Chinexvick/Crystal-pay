import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

class PinGuardState {
  const PinGuardState({this.failures = 0, this.lockedUntil});
  final int failures;
  final DateTime? lockedUntil;

  bool get locked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);
  Duration get remaining => locked ? lockedUntil!.difference(DateTime.now()) : Duration.zero;
  int get attemptsLeft => (Security.pinMaxAttempts - failures).clamp(0, Security.pinMaxAttempts);
}

/// Brute-force protection for the 4-digit PIN. After [Security.pinMaxAttempts]
/// wrong entries the PIN is locked, and each further lock lasts twice as long.
/// The server must enforce the same rule. This only protects the UI.
class PinGuard extends Notifier<PinGuardState> {
  int _locks = 0;

  @override
  PinGuardState build() => const PinGuardState();

  void fail() {
    final f = state.failures + 1;
    if (f >= Security.pinMaxAttempts) {
      _locks++;
      state = PinGuardState(failures: 0, lockedUntil: DateTime.now().add(Security.pinLockout * _locks));
    } else {
      state = PinGuardState(failures: f, lockedUntil: state.lockedUntil);
    }
  }

  void success() {
    _locks = 0;
    state = const PinGuardState();
  }
}

final pinGuardProvider = NotifierProvider<PinGuard, PinGuardState>(PinGuard.new);
