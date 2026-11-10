import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../core/security/validators.dart';
import '../../data/account.dart';
import '../../data/state.dart';

// ───────────────────────── Splash ─────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final s = ref.read(sessionProvider);
      context.go(s.loggedIn ? '/home' : (s.seenOnboarding ? '/signin' : '/onboarding'));
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F2FF),
        body: Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A14DA), Color(0xFF8A57F0), Color(0xFFE6DAFF), Color(0xFFF7F3FF), Color(0xFFEDE3FF)],
                stops: [0, .2, .42, .58, 1],
              ),
            ),
          ),
          // soft glow behind the brand
          Align(
            alignment: const Alignment(0, -.2),
            child: Container(width: 320, height: 320, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withValues(alpha: .75), Colors.white.withValues(alpha: 0)]))),
          ),
          // light streaks across the top, as in the approved splash
          const Positioned.fill(child: CustomPaint(painter: _SplashSwoosh())),
          // the scene is drawn a little wider than the screen so the trees
          // bleed off the edges like the design
          LayoutBuilder(builder: (context, c) {
            final bleed = c.maxWidth * .07;
            return Stack(children: [
              Positioned(left: -bleed, right: -bleed, bottom: 0, child: Image.asset('assets/illustrations/splash_scene.webp', fit: BoxFit.fitWidth, filterQuality: FilterQuality.medium)),
            ]);
          }),
          Align(
            alignment: const Alignment(0, -.22),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const BrandMark(height: 112),
                  const Gap(16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      const TextSpan(children: [TextSpan(text: 'Crystal '), TextSpan(text: 'Pay', style: TextStyle(color: C.primary))]),
                      style: T.display.copyWith(fontSize: 50, letterSpacing: -1.4, color: const Color(0xFF16123A), height: 1.1),
                    ),
                  ),
                  const Gap(8),
                  Text('Shop • Pay • Thrive', style: T.body.copyWith(color: const Color(0xFF2A2560), fontWeight: FontWeight.w600, fontSize: 19)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Two soft white light bands sweeping across the top of the splash.
class _SplashSwoosh extends CustomPainter {
  const _SplashSwoosh();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void band(double y0, double y1, double thick, double alpha) {
      final path = Path()
        ..moveTo(-w * .1, h * y0)
        ..cubicTo(w * .25, h * (y0 - .1), w * .6, h * (y1 + .02), w * 1.1, h * (y1 - .12))
        ..lineTo(w * 1.1, h * (y1 - .12) + thick)
        ..cubicTo(w * .6, h * (y1 + .02) + thick, w * .25, h * (y0 - .1) + thick, -w * .1, h * y0 + thick)
        ..close();
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: alpha), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * .4))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, paint);
    }

    band(.30, .12, h * .05, .16);
    band(.36, .2, h * .028, .12);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ───────────────────────── Onboarding ─────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _p = PageController();
  int _i = 0;

  static const _pages = [
    ('assets/illustrations/onb_shop.webp', 'Shop Smarter', 'Buy anything you need, from top stores and trusted sellers.'),
    ('assets/illustrations/onb_property.webp', 'Find the Right Property', 'Discover lands and houses with ease and confidence.'),
    ('assets/illustrations/onb_bills.webp', 'Pay Bills Instantly', 'Electricity, data, airtime and more, all in one app.'),
  ];

  void _done() {
    ref.read(sessionProvider.notifier).finishOnboarding();
    context.go('/signup');
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(padding: const EdgeInsets.only(right: 14, top: 6), child: TextLink('Skip', trailing: false, onTap: _done)),
          ),
          Expanded(
            child: PageView.builder(
              controller: _p,
              itemCount: _pages.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(children: [
                  Expanded(
                    child: Stack(alignment: Alignment.center, children: [
                      FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: .8,
                        child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFFEFE7FF), const Color(0xFFEFE7FF).withValues(alpha: 0)]))),
                      ),
                      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Image.asset(_pages[i].$1, fit: BoxFit.contain)),
                    ]),
                  ),
                  const Gap(18),
                  Text(_pages[i].$2, style: T.h1.copyWith(fontSize: 27, letterSpacing: -.6), textAlign: TextAlign.center),
                  const Gap(12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: Text(_pages[i].$3, style: T.body.copyWith(color: const Color(0xFF4A4566), fontSize: 15.5, height: 1.5), textAlign: TextAlign.center),
                  ),
                ]),
              ),
            ),
          ),
          const Gap(26),
          Dots(count: _pages.length, index: _i),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
            child: AppButton(
              label: last ? 'Get Started' : 'Next',
              trailingIcon: PhosphorIconsBold.arrowRight,
              onPressed: () => last ? _done() : _p.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Sign in / up (UI only) ─────────────────────────

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.sub, required this.children, this.step, this.showBack = true, this.brand = false});
  final String title, sub;
  final List<Widget> children;

  /// Show the small brand mark above the title (sign-in only).
  final bool brand;

  /// 1-based position in the sign-up journey (shows a progress bar), or null.
  final int? step;
  final bool showBack;

  static const steps = 4;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.surface,
        appBar: AppTopBar(title: '', showBack: showBack),
        body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
          if (step != null) ...[
            Row(children: [
              for (var i = 1; i <= steps; i++) ...[
                Expanded(child: Container(height: 4, decoration: BoxDecoration(color: i <= step! ? C.primary : const Color(0xFFE6E0F2), borderRadius: BorderRadius.circular(2)))),
                if (i < steps) const HGap(6),
              ],
            ]),
            const Gap(8),
            Text('Step $step of $steps', style: T.caption),
            const Gap(18),
          ],
          if (brand) ...[
            const Align(alignment: Alignment.centerLeft, child: BrandMark(height: 40)),
            const Gap(20),
          ],
          Text(title, style: T.h1.copyWith(fontSize: 28)),
          const Gap(8),
          Text(sub, style: T.body.copyWith(color: C.muted)),
          const Gap(28),
          ...children,
        ]),
      );
}

// ───────────────────────── Shared auth widgets ─────────────────────────

class _AuthField extends StatelessWidget {
  const _AuthField({required this.controller, required this.hint, this.icon, this.keyboard, this.obscure = false, this.suffix, this.error, this.onChanged, this.formatters, this.textInputAction, this.autofill});
  final TextEditingController controller;
  final String hint;
  final PhosphorIconData? icon;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  final String? error;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofill;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      onChanged: onChanged,
      inputFormatters: formatters,
      textInputAction: textInputAction ?? TextInputAction.next,
      autofillHints: autofill,
      cursorColor: C.primary,
      style: T.bodyM.copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: T.body.copyWith(color: const Color(0xFF8F8AA6), fontSize: 15),
        prefixIcon: icon == null ? null : Padding(padding: const EdgeInsets.only(left: 16, right: 12), child: PhosphorIcon(icon!, size: 20, color: const Color(0xFF6E6A85))),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        errorText: error,
        errorStyle: T.small.copyWith(color: C.error, fontSize: 12),
        contentPadding: EdgeInsets.fromLTRB(icon == null ? 16 : 0, 16, 12, 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4DFEF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.primary, width: 1.6)),
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.hidden, required this.onTap});
  final bool hidden;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: PhosphorIcon(hidden ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 20, color: const Color(0xFF6E6A85))),
      );
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged, this.error = false});
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        child: Pressable(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? C.primary : (error ? C.errorTint : C.surface),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: value ? C.primary : (error ? C.error : const Color(0xFFC9C3DA)), width: 1.6),
            ),
            child: value ? const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 13, color: Colors.white)) : null,
          ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE6E1F0))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: T.small.copyWith(fontSize: 13))),
        const Expanded(child: Divider(color: Color(0xFFE6E1F0))),
      ]);
}

/// "Continue with Google / Apple" (UI only until social sign-in is connected).
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.asset, required this.provider});
  final String asset;
  final String provider;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => showToast(context, '$provider sign-in will be available soon'),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4DFEF))),
          child: Row(children: [
            SvgPicture.asset('assets/icons/$asset.svg', width: 22, height: 22),
            Expanded(child: Text('Continue with $provider', textAlign: TextAlign.center, style: T.title.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700))),
            const SizedBox(width: 22),
          ]),
        ),
      );
}

class _SwitchLink extends StatelessWidget {
  const _SwitchLink({required this.text, required this.link, required this.onTap});
  final String text;
  final String link;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: T.body.copyWith(fontSize: 14, color: C.ink)),
          TextLink(link, trailing: false, onTap: onTap),
        ]),
      );
}

// ───────────────────────── Login ─────────────────────────

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController(text: 'victory@crystalpay.app');
  final _pass = TextEditingController();
  bool _hide = true;
  bool _remember = true;
  bool _tried = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? get _emailErr => isEmail(_email.text) ? null : 'Enter a valid email address';
  String? get _passErr => _pass.text.length >= 8 ? null : 'Enter your password (at least 8 characters)';

  void _submit() {
    setState(() => _tried = true);
    if (_emailErr != null || _passErr != null) return;
    FocusScope.of(context).unfocus();
    ref.read(accountProvider.notifier).signInAs(_email.text);
    ref.read(sessionProvider.notifier).signIn();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AutofillGroup(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 36, 24, 24), children: [
                const Center(child: BrandMark(height: 64)),
                const Gap(18),
                Text('Welcome Back', textAlign: TextAlign.center, style: T.h1.copyWith(fontSize: 28, letterSpacing: -.6)),
                const Gap(4),
                Text('Sign in to continue', textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted, fontSize: 15)),
                const Gap(30),
                _AuthField(controller: _email, icon: PhosphorIconsRegular.envelopeSimple, hint: 'Email Address', keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], error: _tried ? _emailErr : null, onChanged: (_) => setState(() {})),
                const Gap(14),
                _AuthField(
                  controller: _pass,
                  icon: PhosphorIconsRegular.lock,
                  hint: 'Password',
                  obscure: _hide,
                  autofill: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  error: _tried ? _passErr : null,
                  onChanged: (_) => setState(() {}),
                  suffix: _EyeToggle(hidden: _hide, onTap: () => setState(() => _hide = !_hide)),
                ),
                const Gap(14),
                Row(children: [
                  _Check(value: _remember, onChanged: (v) => setState(() => _remember = v)),
                  const HGap(8),
                  Pressable(onTap: () => setState(() => _remember = !_remember), child: Text('Remember me', style: T.small.copyWith(color: C.ink, fontSize: 13.5))),
                  const Spacer(),
                  TextLink('Forgot Password?', trailing: false, onTap: () => context.push('/forgot')),
                ]),
                const Gap(22),
                AppButton(label: 'Login', onPressed: _submit),
                const Gap(22),
                const _OrDivider(),
                const Gap(18),
                const _SocialButton(asset: 'google', provider: 'Google'),
                const Gap(12),
                const _SocialButton(asset: 'apple', provider: 'Apple'),
                const Gap(28),
                _SwitchLink(text: "Don't have an account? ", link: 'Sign Up', onTap: () => context.go('/signup')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Create account ─────────────────────────

/// Accepts 08012345678, 8012345678 or 2348012345678 and returns 08012345678.
String? normaliseSignupPhone(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  String? n;
  if (d.length == 11 && d.startsWith('0')) n = d;
  if (d.length == 10 && !d.startsWith('0')) n = '0$d';
  if (d.length == 13 && d.startsWith('234')) n = '0${d.substring(3)}';
  return n != null && isNgPhone(n) ? n : null;
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _agree = false;
  bool _tried = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  List<String> get _names => _name.text.trim().split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
  String? get _nameErr => _names.length >= 2 ? null : 'Enter your first and last name as on your ID';
  String? get _emailErr => isEmail(_email.text) ? null : 'Enter a valid email address';
  String? get _phoneErr => normaliseSignupPhone(_phone.text) != null ? null : 'Enter a valid phone number';
  String? get _passErr => passwordProblem(_pass.text);

  void _submit() {
    setState(() => _tried = true);
    if (_nameErr != null || _emailErr != null || _phoneErr != null || _passErr != null) return;
    if (!_agree) {
      showToast(context, 'Please accept the Terms & Conditions and Privacy Policy', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final n = ref.read(accountProvider.notifier);
    n.startSignup(_email.text);
    n.setDetails(firstName: _names.first, lastName: _names.sublist(1).join(' '), phone: normaliseSignupPhone(_phone.text)!);
    context.push('/otp?email=${Uri.encodeQueryComponent(_email.text.trim())}');
  }

  void _countrySheet() {
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetFrame(
        title: 'Country',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Pressable(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.primary)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset('assets/flags/ng.png', width: 28, height: 20, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 28))),
                const HGap(12),
                Expanded(child: Text('Nigeria', style: T.title)),
                Text('+234', style: T.title.copyWith(color: C.primary)),
              ]),
            ),
          ),
          const Gap(12),
          Text('Crystal Pay is available in Nigeria. More countries are coming soon.', style: T.small),
        ]),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return AutofillGroup(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            onTap: () => context.canPop() ? context.pop() : context.go('/signin'),
            child: const SizedBox(width: 44, height: 44, child: Center(child: PhosphorIcon(PhosphorIconsBold.caretLeft, size: 22, color: C.ink))),
          ),
        ),
        const Center(child: BrandMark(height: 56)),
        const Gap(14),
        Text('Create Account', textAlign: TextAlign.center, style: T.h1.copyWith(fontSize: 27, letterSpacing: -.6)),
        const Gap(4),
        Text('Join Crystal Pay today', textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted, fontSize: 15)),
        const Gap(24),
        _AuthField(controller: _name, icon: PhosphorIconsRegular.user, hint: 'Full Name', keyboard: TextInputType.name, autofill: const [AutofillHints.name], error: _tried ? _nameErr : null, onChanged: (_) => setState(() {})),
        const Gap(12),
        _AuthField(controller: _email, icon: PhosphorIconsRegular.envelopeSimple, hint: 'Email Address', keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], error: _tried ? _emailErr : null, onChanged: (_) => setState(() {})),
        const Gap(12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Pressable(
            onTap: _countrySheet,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4DFEF))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const PhosphorIcon(PhosphorIconsRegular.phone, size: 19, color: Color(0xFF6E6A85)),
                const HGap(8),
                Text('+234', style: T.bodyM.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                const HGap(4),
                const PhosphorIcon(PhosphorIconsBold.caretDown, size: 12, color: C.ink),
              ]),
            ),
          ),
          const HGap(10),
          Expanded(
            child: _AuthField(
              controller: _phone,
              hint: 'Phone Number',
              keyboard: TextInputType.phone,
              autofill: const [AutofillHints.telephoneNumberNational],
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
              error: _tried ? _phoneErr : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const Gap(12),
        _AuthField(
          controller: _pass,
          icon: PhosphorIconsRegular.lock,
          hint: 'Password',
          obscure: _hide,
          autofill: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          error: _tried ? _passErr : null,
          onChanged: (_) => setState(() {}),
          suffix: _EyeToggle(hidden: _hide, onTap: () => setState(() => _hide = !_hide)),
        ),
        const Gap(16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: _Check(value: _agree, error: _tried && !_agree, onChanged: (v) => setState(() => _agree = v))),
          const HGap(10),
          Expanded(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pressable(onTap: () => setState(() => _agree = !_agree), child: Text('I agree to the ', style: T.small.copyWith(color: C.ink, fontSize: 13.5))),
              Pressable(onTap: () => context.push('/legal/terms'), child: Text('Terms & Conditions', style: T.small.copyWith(color: C.primary, fontSize: 13.5, fontWeight: FontWeight.w700))),
              Text(' and ', style: T.small.copyWith(color: C.ink, fontSize: 13.5)),
              Pressable(onTap: () => context.push('/legal/privacy'), child: Text('Privacy Policy', style: T.small.copyWith(color: C.primary, fontSize: 13.5, fontWeight: FontWeight.w700))),
            ]),
          ),
        ]),
        const Gap(22),
        AppButton(label: 'Create Account', onPressed: _submit),
        const Gap(22),
        _SwitchLink(text: 'Already have an account? ', link: 'Login', onTap: () => context.go('/signin')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 760) return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: _form(context)));
          // Tablets: the form beside the brand character, as in the design.
          return Row(children: [
            Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: _form(context)))),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: C.heroGradient, borderRadius: BorderRadius.circular(32)),
                alignment: Alignment.bottomCenter,
                child: Image.asset('assets/illustrations/character.webp', fit: BoxFit.contain),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.email});
  final String email;
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  int _left = 30;
  Timer? _t;
  String? _err;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left == 0) {
        t.cancel();
      } else if (mounted) {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(title: 'Verify Your Email', sub: 'Enter the 4-digit code we sent to ${widget.email}.\nDemo: any code works except 0000.', children: [
      PinEntry(
        error: _err,
        onComplete: (code) {
          if (code == '0000') {
            setState(() => _err = 'Incorrect code. Try again');
            return;
          }
          context.go('/signup/details');
        },
      ),
      const Gap(10),
      Center(child: _left > 0 ? Text('Resend code in 0:${_left.toString().padLeft(2, '0')}', style: T.small) : TextLink('Resend code', trailing: false, onTap: () => setState(() => _left = 30))),
    ]);
  }
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _email = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(title: 'Reset Password', sub: 'Enter your email and we will send you a reset link.', children: [
      AppTextField(controller: _email, label: 'Email address', hint: 'you@example.com', keyboard: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
      const Gap(24),
      AppButton(label: 'Send reset link', onPressed: isEmail(_email.text) ? () {
        showToast(context, 'Reset link sent to your email');
        context.pop();
      } : null),
    ]);
  }
}
