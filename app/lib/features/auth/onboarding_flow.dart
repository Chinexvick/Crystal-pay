import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/security/biometric.dart';
import '../../core/security/validators.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../api/sync.dart';
import '../../data/account.dart';
import '../../data/state.dart';
import '../me/photo_picker.dart';
import 'auth_screens.dart';

// ───────────────────────── Step 2: personal details ─────────────────────────

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});
  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  // Name and phone come from Create Account; confirm them here.
  late final _first = TextEditingController(text: ref.read(accountProvider).firstName);
  late final _last = TextEditingController(text: ref.read(accountProvider).lastName);
  late final _phone = TextEditingController(text: ref.read(accountProvider).phone);
  late final _user = TextEditingController(text: ref.read(accountProvider).firstName.isEmpty ? '' : suggestUsername(ref.read(accountProvider).firstName));
  bool _userEdited = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _user.dispose();
    super.dispose();
  }

  String get _handle => _user.text.trim().toLowerCase().replaceFirst('@', '');
  bool get _ok => _first.text.trim().length >= 2 && _last.text.trim().length >= 2 && isNgPhone(_phone.text) && isValidUsername(_handle);

  @override
  Widget build(BuildContext context) {
    final phoneErr = _phone.text.length >= 11 && !isNgPhone(_phone.text) ? 'Enter a valid Nigerian number' : null;
    return AuthScaffold(
      step: 2,
      title: 'Complete Your Profile',
      sub: 'Check your name matches your ID exactly, then add a photo and pick a username.',
      children: [
        Center(child: ProfilePhotoPicker(size: 96, nameOverride: _first.text)),
        const Gap(8),
        Center(child: Text('Add a profile photo (optional)', style: T.small)),
        const Gap(22),
        AppTextField(
          controller: _first,
          label: 'First name',
          hint: 'e.g. Victory',
          onChanged: (v) => setState(() {
            if (!_userEdited) _user.text = v.trim().isEmpty ? '' : suggestUsername(v);
          }),
          formatters: [LengthLimitingTextInputFormatter(40)],
        ),
        const Gap(16),
        AppTextField(controller: _last, label: 'Last name', hint: 'e.g. Bassey', onChanged: (_) => setState(() {}), formatters: [LengthLimitingTextInputFormatter(40)]),
        const Gap(16),
        AppTextField(
          controller: _phone,
          label: 'Phone number',
          hint: '080 0000 0000',
          keyboard: TextInputType.phone,
          error: phoneErr,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          onChanged: (_) => setState(() {}),
          helper: 'This becomes your default number for airtime and data. You can change it on any purchase.',
        ),
        const Gap(16),
        AppTextField(
          controller: _user,
          label: 'Username',
          hint: 'yourname',
          prefix: Text('@', style: T.bodyM.copyWith(fontSize: 15, color: C.muted)),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')), LengthLimitingTextInputFormatter(20)],
          onChanged: (_) => setState(() => _userEdited = true),
          error: _user.text.isNotEmpty && !isValidUsername(_handle) ? '3 to 20 letters, numbers, dots or underscores' : null,
          helper: 'Friends can send you money with this. You can change it later.',
        ),
        const Gap(28),
        AppButton(
          label: 'Continue',
          onPressed: _ok
              ? () {
                  ref.read(accountProvider.notifier).setDetails(firstName: _first.text, lastName: _last.text, phone: _phone.text, username: _handle);
                  context.push('/signup/verify-id');
                }
              : null,
        ),
      ],
    );
  }
}

// ───────────────────────── Step 3: identity verification ─────────────────────────

/// BVN / NIN checks are switched off for now. Every user can skip and use the
/// whole app. The server records the choice and emails a confirmation.
class VerifyIdScreen extends ConsumerStatefulWidget {
  const VerifyIdScreen({super.key, this.onboarding = false});
  final bool onboarding;
  @override
  ConsumerState<VerifyIdScreen> createState() => _VerifyIdScreenState();
}

class _VerifyIdScreenState extends ConsumerState<VerifyIdScreen> {
  bool _busy = false;

  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      final me = await ref.read(apiProvider).post('/me/kyc/skip');
      ref.read(accountProvider.notifier).applyServer(me);
    } catch (_) {/* skipping must never block the user */}
    if (!mounted) return;
    widget.onboarding ? context.go('/signup/biometric') : context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      step: widget.onboarding ? 3 : null,
      title: 'Verify Your Identity',
      sub: 'BVN and ID verification is coming soon. You can skip it now and use Crystal Pay as normal.',
      children: [
        Opacity(
          opacity: .5,
          child: IgnorePointer(
            child: Column(children: [
              AppTextField(label: 'BVN or NIN (11 digits)', hint: '00000000000', readOnly: true),
              const Gap(12),
              AppButton(label: 'Verify', onPressed: null),
            ]),
          ),
        ),
        const Gap(14),
        const InfoBanner('Verification will unlock higher limits and the blue tick. You will be able to add it later from Me.'),
        const Gap(22),
        AppButton(label: 'Skip for now', loading: _busy, onPressed: _skip),
      ],
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) => n.copyWith(text: n.text.toUpperCase());
}

// ───────────────────────── Step 4: fingerprint lock ─────────────────────────

class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});
  @override
  ConsumerState<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _busy = false;

  void _finish() {
    ref.read(sessionProvider.notifier).signIn();
    context.go('/home');
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final available = await Biometrics.available();
    if (!available) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, 'No fingerprint is set up on this phone. Add one in your phone settings first.', error: true);
      return;
    }
    final ok = await Biometrics.authenticate('Confirm your fingerprint to turn on the app lock');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(accountProvider.notifier).setBiometric(true);
      _finish();
    } else {
      showToast(context, 'Fingerprint not confirmed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      step: 4,
      showBack: false,
      title: 'Turn On Fingerprint Lock',
      sub: 'Open Crystal Pay with a touch instead of typing. You can turn it off or on any time in Security settings.',
      children: [
        const Gap(12),
        const Center(child: IconChip(PhosphorIconsDuotone.fingerprint, size: 120, circle: true, iconSize: 64)),
        const Gap(36),
        AppButton(label: 'Turn on fingerprint lock', loading: _busy, onPressed: _busy ? null : _enable),
        const Gap(8),
        Center(child: TextLink('Not now', trailing: false, color: C.muted, onTap: _finish)),
      ],
    );
  }
}
