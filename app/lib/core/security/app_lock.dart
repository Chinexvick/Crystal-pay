import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/state.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import '../config/app_config.dart';
import 'biometric.dart';
import 'pin_guard.dart';
import '../../data/account.dart';

/// Wraps the whole app. It:
///  * hides content while the app is backgrounded (task-switcher privacy), and
///  * demands the PIN again after [Security.autoLockAfter] in the background.
/// Only active while signed in.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  DateTime? _left;
  bool _cover = false;
  bool _locked = false;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final signedIn = ref.read(sessionProvider).loggedIn;
    if (!signedIn) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _left ??= DateTime.now();
        setState(() => _cover = true);
      case AppLifecycleState.resumed:
        final away = _left == null ? Duration.zero : DateTime.now().difference(_left!);
        _left = null;
        setState(() {
          _cover = false;
          if (away >= Security.autoLockAfter) _locked = true;
        });
        if (_locked && ref.read(accountProvider).biometric) _bio();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _bio() async {
    final ok = await Biometrics.authenticate('Unlock Crystal Pay');
    if (ok && mounted) {
      ref.read(pinGuardProvider.notifier).success();
      setState(() {
        _locked = false;
        _error = null;
      });
    }
  }

  void _unlock(String pin) {
    final guard = ref.read(pinGuardProvider.notifier);
    if (ref.read(pinGuardProvider).locked) return;
    if (pin == '0000') {
      guard.fail();
      final g = ref.read(pinGuardProvider);
      setState(() => _error = g.locked ? 'Too many attempts' : 'Incorrect PIN · ${g.attemptsLeft} attempts left');
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!ref.read(pinGuardProvider).locked) _tick?.cancel();
      });
      return;
    }
    guard.success();
    setState(() {
      _locked = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionProvider).loggedIn;
    final g = ref.watch(pinGuardProvider);
    return Stack(children: [
      widget.child,
      if (signedIn && _locked)
        Positioned.fill(
          child: Material(
            color: C.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.page),
                child: Column(children: [
                  const Spacer(),
                  const BrandMark(height: 56),
                  const Gap(18),
                  Text('Welcome back', style: T.h1),
                  const Gap(6),
                  Text(ref.watch(accountProvider).biometric ? 'Use your fingerprint or enter your PIN' : 'Enter your PIN to unlock Crystal Pay', style: T.small.copyWith(fontSize: 14)),
                  const Gap(28),
                  if (g.locked)
                    Column(children: [
                      const PhosphorIcon(PhosphorIconsDuotone.lockKey, size: 44, color: C.error),
                      const Gap(10),
                      Text('Try again in 0:${(g.remaining.inSeconds + 1).toString().padLeft(2, '0')}', style: T.small.copyWith(fontSize: 14)),
                    ])
                  else
                    PinEntry(onComplete: _unlock, error: _error),
                  if (ref.watch(accountProvider).biometric) ...[
                    const Gap(18),
                    Pressable(onTap: _bio, child: const IconChip(PhosphorIconsDuotone.fingerprint, size: 64, circle: true, iconSize: 34)),
                  ],
                  const Spacer(),
                  TextLink('Log out', trailing: false, color: C.error, onTap: () {
                    ref.read(sessionProvider.notifier).signOut();
                    setState(() => _locked = false);
                    ref.read(routerProvider).go('/welcome');
                  }),
                  const Gap(12),
                ]),
              ),
            ),
          ),
        )
      else if (signedIn && _cover)
        Positioned.fill(
          child: ColoredBox(color: C.surface, child: Center(child: const BrandMark(height: 56))),
        ),
    ]);
  }
}
