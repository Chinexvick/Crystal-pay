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

/// NIN, BVN or international passport. Only a successful check earns the blue tick.
/// Front-end demo: a number ending in 0 simulates a failed lookup.
class VerifyIdScreen extends ConsumerStatefulWidget {
  const VerifyIdScreen({super.key, this.onboarding = false});
  final bool onboarding;
  @override
  ConsumerState<VerifyIdScreen> createState() => _VerifyIdScreenState();
}

enum _Phase { form, checking, done }

class _VerifyIdScreenState extends ConsumerState<VerifyIdScreen> {
  IdType _type = IdType.nin;
  final _no = TextEditingController();
  bool _consent = false;
  _Phase _phase = _Phase.form;
  String? _error;

  @override
  void dispose() {
    _no.dispose();
    super.dispose();
  }

  bool get _valid => _type == IdType.passport ? isPassportNo(_no.text) : isEleven(_no.text);

  String get _hint => switch (_type) {
        IdType.nin => 'Dial *346# on your registered line, or open your NIN slip.',
        IdType.bvn => 'Dial *565*0# on your registered line to see your BVN.',
        IdType.passport => 'Use the number on the photo page of your passport.',
      };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    if (_no.text.trim().endsWith('0')) {
      setState(() {
        _phase = _Phase.form;
        _error = 'We could not match this ${_type.short} to your name. Check the number and that your name is spelled exactly as on the ID.';
      });
      return;
    }
    ref.read(accountProvider.notifier).markVerified(_type);
    setState(() => _phase = _Phase.done);
  }

  void _next() => widget.onboarding ? context.go('/signup/biometric') : context.pop();

  @override
  Widget build(BuildContext context) {
    final acct = ref.watch(accountProvider);
    if (_phase == _Phase.checking) {
      return Scaffold(
        backgroundColor: C.surface,
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3.2, color: C.primary, strokeCap: StrokeCap.round)),
              const Gap(22),
              Text('Verifying your identity', style: T.h2),
              const Gap(6),
              Text('This only takes a moment', style: T.small),
            ]),
          ),
        ),
      );
    }
    if (_phase == _Phase.done) {
      return Scaffold(
        backgroundColor: C.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sp.page),
            child: Column(children: [
              const Spacer(),
              const PhosphorIcon(PhosphorIconsFill.sealCheck, size: 96, color: C.primary),
              const Gap(22),
              Text('You are verified', style: T.h1.copyWith(fontSize: 26)),
              const Gap(10),
              Text('${acct.fullName}, your ${acct.idType?.short ?? 'ID'} has been confirmed. A blue tick now shows on your profile and your limits are raised.', textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted, height: 1.45)),
              const Spacer(),
              AppButton(label: 'Continue', onPressed: _next),
            ]),
          ),
        ),
      );
    }
    return AuthScaffold(
      step: widget.onboarding ? 3 : null,
      title: 'Verify Your Identity',
      sub: 'Choose one ID to confirm it is really you. It unlocks withdrawals, higher limits and the blue tick.',
      children: [
        Row(children: [
          for (final t in IdType.values) ...[
            Expanded(
              child: Pressable(
                onTap: () => setState(() {
                  _type = t;
                  _no.clear();
                  _error = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t == _type ? C.primary : C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t == _type ? C.primary : C.border),
                  ),
                  child: Text(t.short, style: T.label.copyWith(color: t == _type ? Colors.white : C.ink, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            if (t != IdType.values.last) const HGap(8),
          ],
        ]),
        const Gap(20),
        AppTextField(
          controller: _no,
          label: _type == IdType.passport ? 'Passport number' : '${_type.label} (11 digits)',
          hint: _type == IdType.passport ? 'A12345678' : '00000000000',
          keyboard: _type == IdType.passport ? TextInputType.text : TextInputType.number,
          formatters: _type == IdType.passport
              ? [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(9), UpperCaseFormatter()]
              : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          helper: _hint,
          onChanged: (_) => setState(() => _error = null),
        ),
        const Gap(16),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PhosphorIcon(PhosphorIconsDuotone.userCheck, size: 22, color: C.primary),
            const HGap(12),
            Expanded(child: Text('We will confirm this against ${acct.fullName.isEmpty ? 'your name' : acct.fullName.toUpperCase()}. Your ID number is encrypted and never shown again.', style: T.small.copyWith(fontSize: 13, height: 1.4))),
          ]),
        ),
        if (_error != null) ...[const Gap(12), InfoBanner(_error!, kind: BannerKind.error)],
        const Gap(16),
        Pressable(
          onTap: () => setState(() => _consent = !_consent),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: _consent ? C.primary : C.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: _consent ? C.primary : C.border, width: 1.6)),
              child: _consent ? const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 14, color: Colors.white)) : null,
            ),
            const HGap(10),
            Expanded(child: Text('I allow Crystal Pay to verify my details with the issuing authority.', style: T.small.copyWith(fontSize: 13))),
          ]),
        ),
        const Gap(24),
        AppButton(label: 'Verify', onPressed: (_valid && _consent) ? _submit : null),
        if (widget.onboarding) ...[
          const Gap(8),
          Center(child: TextLink('Do this later', trailing: false, color: C.muted, onTap: () => context.go('/signup/biometric'))),
        ],
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
