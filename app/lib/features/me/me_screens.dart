import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../core/security/biometric.dart';
import '../../core/utils/pick_photos.dart';
import '../../data/account.dart';
import '../../data/plans.dart';
import 'photo_picker.dart';
import '../../data/mock_data.dart';
import '../../data/state.dart';

/// "More" tab, modelled on the approved design: profile, wallet card,
/// money shortcuts, then the account menu.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acct = ref.watch(accountProvider);
    final unreadChats = ref.watch(unreadChatsProvider);
    final unreadNotes = ref.watch(unreadNotesProvider);
    final w = ref.watch(walletProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    final items = <_Item>[
      _Item('orders', 'My Orders', 'Track your purchases and sales', '/orders'),
      _Item('store', 'My Listings', 'Manage your shop and properties', '/my-listings'),
      _Item('favorites', 'Favorites', 'Your saved items', '/saved'),
      _Item('messages', 'Messages', 'Chats with buyers and sellers', '/chats', badge: unreadChats),
      _Item('crown', 'Seller Plan', acct.planActive ? '${planById(acct.plan!).name} plan is active' : 'Subscribe to start selling', '/plans'),
      _Item('security', 'Security', 'PIN, password and fingerprint', '/settings/security'),
      _Item('gift', 'Refer & Earn', 'Invite friends, get ₦500 each', '/refer'),
      _Item('help', 'Help & Support', 'Get help whenever you need it', '/help'),
      _Item('info', 'About Crystal Pay', 'Learn more about us', '/about'),
    ];
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        TabHeader(title: 'More', actions: [HeaderIcon(icon: PhosphorIconsRegular.bell, dot: unreadNotes > 0, onTap: () => context.push('/notifications'))]),
        const Gap(18),
        // Profile
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.page),
          child: Pressable(
            onTap: () => context.push('/settings/profile'),
            scale: .99,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: C.tint, shape: BoxShape.circle),
                child: Avatar(asset: acct.photo, name: acct.fullName, size: 76),
              ),
              const HGap(16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(acct.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.h2.copyWith(fontWeight: FontWeight.w800, fontSize: 19, height: 1.2)),
                  if (acct.username.isNotEmpty) Text('@${acct.username}', style: T.small.copyWith(fontSize: 13.5)),
                  const Gap(8),
                  Pressable(
                    onTap: acct.idVerified ? null : () => context.push('/settings/verify-id'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: acct.idVerified ? C.tint : C.goldTint, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PhosphorIcon(acct.idVerified ? PhosphorIconsFill.sealCheck : PhosphorIconsFill.warningCircle, size: 15, color: acct.idVerified ? C.primary : C.pending),
                        const HGap(5),
                        Text(acct.idVerified ? 'Verified User' : 'Verify your identity', style: T.label.copyWith(color: acct.idVerified ? C.primary : C.pending, fontSize: 12.5)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: PhosphorIcon(PhosphorIconsBold.caretRight, size: 15, color: C.primary)),
              ),
            ]),
          ),
        ),
        const Gap(20),
        // Wallet card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.page),
          child: Pressable(
            onTap: () => context.push('/wallet'),
            scale: .985,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
              decoration: BoxDecoration(gradient: C.deepGradient, borderRadius: BorderRadius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(right: -60, top: -70, child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
                Positioned(right: 40, bottom: -90, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .05)))),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const PhosphorIcon(PhosphorIconsFill.wallet, size: 20, color: Colors.white),
                        const HGap(8),
                        Text('Wallet Balance', style: T.smallM.copyWith(color: Colors.white.withValues(alpha: .85), fontSize: 13)),
                        const HGap(8),
                        Pressable(
                          onTap: () => ref.read(balanceHiddenProvider.notifier).toggle(),
                          child: PhosphorIcon(hidden ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 17, color: Colors.white.withValues(alpha: .85)),
                        ),
                      ]),
                      const Gap(10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(hidden ? '₦ ••••••' : money2(w.balance), style: T.moneyOf(30, color: Colors.white)),
                      ),
                    ]),
                  ),
                  const HGap(10),
                  Pressable(
                    onTap: () => context.push('/wallet/add'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .8), width: 1.3)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Fund Wallet', style: T.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        const HGap(6),
                        const PhosphorIcon(PhosphorIconsBold.arrowRight, size: 14, color: Colors.white),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
        const Gap(14),
        // Money shortcuts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.page),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFF0E8FE), borderRadius: BorderRadius.circular(20)),
            child: IntrinsicHeight(
              child: Row(children: [
                _Quick(PhosphorIconsRegular.paperPlaneTilt, 'Send\nMoney', () => context.push('/send')),
                const _VDiv(),
                _Quick(PhosphorIconsRegular.downloadSimple, 'Withdraw', () => context.push('/wallet/withdraw')),
                const _VDiv(),
                _Quick(PhosphorIconsRegular.clockCounterClockwise, 'Transaction\nHistory', () => context.push('/transactions')),
                const _VDiv(),
                _Quick(PhosphorIconsRegular.headset, 'Support', () => context.push('/help')),
              ]),
            ),
          ),
        ),
        const Gap(18),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 10),
            child: AppCard(
              onTap: () => context.push(it.route),
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(children: [
                IconTile(it.icon, size: 48, bg: C.tint2),
                const HGap(14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.title, style: T.title.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const Gap(1),
                    Text(it.sub, style: T.small.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (it.badge > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: C.error, borderRadius: BorderRadius.circular(10)),
                    child: Text('${it.badge}', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                const PhosphorIcon(PhosphorIconsBold.caretRight, size: 16, color: C.ink),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 0),
          child: AppButton(
            label: 'Log Out',
            kind: BtnKind.soft,
            icon: PhosphorIconsRegular.signOut,
            onPressed: () => showAppSheet<void>(context, builder: (ctx) => SheetFrame(
              title: 'Log out?',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('You will need to sign in again to use your wallet.', style: T.small.copyWith(fontSize: 13.5)),
                const Gap(20),
                AppButton(label: 'Log Out', kind: BtnKind.danger, onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(sessionProvider.notifier).signOut();
                  context.go('/welcome');
                }),
                const Gap(10),
                AppButton(label: 'Stay Signed In', kind: BtnKind.soft, onPressed: () => Navigator.pop(ctx)),
              ]),
            )),
          ),
        ),
        const Gap(8),
        Center(child: Text('Version 1.0.0', style: T.caption)),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.onTap);
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PhosphorIcon(icon, size: 26, color: C.primary),
            const Gap(8),
            Text(label, textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _VDiv extends StatelessWidget {
  const _VDiv();
  @override
  Widget build(BuildContext context) => Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFFDCCFF7));
}

class _Item {
  const _Item(this.icon, this.title, this.sub, this.route, {this.badge = 0});
  final String icon;
  final String title, sub, route;
  final int badge;
}

// ───────────────────────── Settings ─────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _phone = TextEditingController(text: ref.read(accountProvider).phone);
  late final _city = TextEditingController(text: ref.read(accountProvider).city);
  late final _user = TextEditingController(text: ref.read(accountProvider).username);

  @override
  void dispose() {
    _phone.dispose();
    _city.dispose();
    _user.dispose();
    super.dispose();
  }

  String get _handle => _user.text.trim().toLowerCase().replaceFirst('@', '');

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(accountProvider);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Profile'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        const Center(child: ProfilePhotoPicker(size: 96)),
        const Gap(10),
        Center(child: TextLink('Change photo', trailing: false, onTap: () async {
          final got = await pickPhotos(context);
          if (got.isNotEmpty) ref.read(accountProvider.notifier).setPhoto(got.first);
        })),
        const Gap(14),
        AppTextField(controller: TextEditingController(text: a.fullName), label: 'Full name', readOnly: true, helper: a.idVerified ? 'Locked to the name on your ${a.idType?.short ?? 'ID'}' : null),
        const Gap(14),
        AppTextField(controller: TextEditingController(text: a.email), label: 'Email address', readOnly: true),
        const Gap(14),
        AppTextField(controller: _phone, label: 'Phone number', keyboard: TextInputType.phone, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)], helper: 'Your default number for airtime and data'),
        const Gap(14),
        AppTextField(
          controller: _user,
          label: 'Username',
          prefix: Text('@', style: T.bodyM.copyWith(fontSize: 15, color: C.muted)),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')), LengthLimitingTextInputFormatter(20)],
          onChanged: (_) => setState(() {}),
          error: _user.text.isNotEmpty && !isValidUsername(_handle) ? '3 to 20 letters, numbers, dots or underscores' : null,
          helper: 'People send you money with @${_handle.isEmpty ? 'username' : _handle}',
        ),
        const Gap(14),
        AppTextField(controller: _city, label: 'City'),
        const Gap(14),
        if (!a.idVerified) InfoBanner('Your identity is not verified yet. Verify to withdraw, sell and get the blue tick.', kind: BannerKind.warning, action: 'Verify now', onAction: () => context.push('/settings/verify-id')),
        const Gap(28),
        AppButton(label: 'Save Changes', onPressed: isNgPhone(_phone.text) && isValidUsername(_handle) ? () {
          ref.read(accountProvider.notifier).setPhone(_phone.text);
          ref.read(accountProvider.notifier).setUsername(_handle);
          ref.read(accountProvider.notifier).setCity(_city.text.trim());
          showToast(context, 'Profile updated');
          context.pop();
        } : null),
      ]),
    );
  }
}

/// Turning the lock on or off both require a fingerprint, so a borrowed
/// unlocked phone cannot change it.
Future<void> _toggleBio(BuildContext context, WidgetRef ref, bool on) async {
  if (!await Biometrics.available()) {
    if (context.mounted) showToast(context, 'Set up a fingerprint in your phone settings first', error: true);
    return;
  }
  final ok = await Biometrics.authenticate(on ? 'Confirm your fingerprint to turn on the app lock' : 'Confirm your fingerprint to turn off the app lock');
  if (ok) {
    ref.read(accountProvider.notifier).setBiometric(on);
  } else if (context.mounted) {
    showToast(context, 'Fingerprint not confirmed', error: true);
  }
}

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(prefsProvider);
    final acct = ref.watch(accountProvider);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Security'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            _Row(PhosphorIconsDuotone.password, 'Change transaction PIN', 'Used to approve payments', onTap: () => showAppSheet<void>(context, builder: (_) => const _ChangePinSheet())),
            const HairDivider(indent: 54),
            _Row(PhosphorIconsDuotone.lockKey, 'Change password', 'Last changed 3 months ago', onTap: () => showToast(context, 'Password reset link sent to your email', icon: PhosphorIconsFill.envelopeSimple)),
            const HairDivider(indent: 54),
            _Row(PhosphorIconsDuotone.fingerprint, 'Fingerprint lock', 'Unlock the app with your fingerprint', trailing: Switch(value: acct.biometric, onChanged: (v) => _toggleBio(context, ref, v))),
            const HairDivider(indent: 54),
            _Row(PhosphorIconsDuotone.eyeSlash, 'Hide balance on open', 'Wallet balance starts hidden', trailing: Switch(value: p.hideBalanceOnOpen, onChanged: (v) => ref.read(prefsProvider.notifier).set(p.copyWith(hideBalanceOnOpen: v)))),
          ]),
        ),
        const Gap(18),
        const InfoBanner('Crystal Pay will never ask for your PIN or OTP by phone, SMS or chat.'),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.title, this.sub, {this.onTap, this.trailing});
  final PhosphorIconData icon;
  final String title, sub;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: .99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            IconChip(icon, size: 40, iconSize: 21),
            const HGap(14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.title),
                if (sub.isNotEmpty) Text(sub, style: T.small.copyWith(fontSize: 12)),
              ]),
            ),
            trailing ?? const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
          ]),
        ),
      );
}

class _ChangePinSheet extends StatefulWidget {
  const _ChangePinSheet();
  @override
  State<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<_ChangePinSheet> {
  int _phase = 0;
  String _first = '';
  String? _err;
  @override
  Widget build(BuildContext context) {
    const heads = ['Enter current PIN', 'Enter new PIN', 'Confirm new PIN'];
    return SheetFrame(
      title: heads[_phase],
      child: PinEntry(
        key: ValueKey(_phase),
        error: _err,
        onComplete: (pin) {
          if (_phase == 0) {
            setState(() {
              _phase = 1;
              _err = null;
            });
          } else if (_phase == 1) {
            setState(() {
              _first = pin;
              _phase = 2;
            });
          } else if (pin != _first) {
            setState(() {
              _err = 'PINs do not match';
              _phase = 1;
            });
          } else {
            Navigator.pop(context);
            showToast(context, 'Transaction PIN changed');
          }
        },
      ),
    );
  }
}

class NotifSettingsScreen extends ConsumerWidget {
  const NotifSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Notifications'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            _Row(PhosphorIconsDuotone.package, 'Orders and offers', 'Updates on purchases and sales', trailing: Switch(value: p.pushOrders, onChanged: (v) => n.set(p.copyWith(pushOrders: v)))),
            const HairDivider(indent: 54),
            _Row(PhosphorIconsDuotone.receipt, 'Bill payments', 'Receipts and tokens', trailing: Switch(value: p.pushBills, onChanged: (v) => n.set(p.copyWith(pushBills: v)))),
            const HairDivider(indent: 54),
            _Row(PhosphorIconsDuotone.gift, 'Promos and cashback', 'Deals we think you will like', trailing: Switch(value: p.pushPromos, onChanged: (v) => n.set(p.copyWith(pushPromos: v)))),
          ]),
        ),
      ]),
    );
  }
}

// ───────────────────────── Help / refer / about ─────────────────────────

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int _open = -1;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Help & Support'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        Row(children: [
          Expanded(child: _Contact(PhosphorIconsDuotone.chatsCircle, 'Live chat', () => context.push('/help/chat'))),
          const HGap(12),
          Expanded(child: _Contact(PhosphorIconsDuotone.envelopeSimple, 'Email us', () => showToast(context, 'support@crystalpay.app', icon: PhosphorIconsFill.envelopeSimple))),
        ]),
        const Gap(24),
        Text('Frequently asked', style: T.h3),
        const Gap(12),
        for (var i = 0; i < mockFaqs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => setState(() => _open = _open == i ? -1 : i),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(mockFaqs[i].$1, style: T.title.copyWith(fontSize: 14.5))),
                  AnimatedRotation(turns: _open == i ? .5 : 0, duration: const Duration(milliseconds: 180), child: const PhosphorIcon(PhosphorIconsBold.caretDown, size: 15, color: C.muted)),
                ]),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _open == i ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(padding: const EdgeInsets.only(top: 10), child: Text(mockFaqs[i].$2, style: T.small.copyWith(fontSize: 13.5, height: 1.5))),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact(this.icon, this.label, this.onTap);
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Column(children: [
          IconChip(icon, size: 48, iconSize: 26),
          const Gap(10),
          Text(label, style: T.title),
        ]),
      );
}

class ReferScreen extends ConsumerWidget {
  const ReferScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Refer & Earn'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        Container(
          height: 210,
          decoration: BoxDecoration(gradient: C.bannerGradient, borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(right: -6, bottom: -40, top: 6, child: Image.asset('assets/illustrations/character.webp', fit: BoxFit.fitHeight)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 150, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Give ₦500,\nGet ₦500', style: T.h1.copyWith(color: Colors.white, fontSize: 25, height: 1.15)),
                const Gap(8),
                Text('When a friend signs up with your code and makes their first payment, you both earn ₦500.', style: T.small.copyWith(color: Colors.white.withValues(alpha: .88), fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const Gap(22),
        AppCard(
          child: Column(children: [
            Text('Your referral code', style: T.small),
            const Gap(6),
            Text('${acctFirst(ref)}500', style: T.moneyOf(26, color: C.primary)),
            const Gap(16),
            AppButton(label: 'Copy Code', icon: PhosphorIconsRegular.copy, kind: BtnKind.secondary, onPressed: () => showToast(context, 'Referral code copied')),
          ]),
        ),
        const Gap(14),
        AppButton(label: 'Share With Friends', icon: PhosphorIconsRegular.shareNetwork, onPressed: () => showToast(context, 'Share sheet opens on device')),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'About Crystal Pay'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 24, Sp.page, 32), children: [
        const Center(child: BrandMark(height: 96)),
        const Gap(14),
        Center(child: Text('Crystal Pay', style: T.h1)),
        Center(child: Text('Version 1.0.0', style: T.small)),
        const Gap(22),
        Text('Pay your bills and buy or sell items safely, all from one wallet.', textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted)),
        const Gap(26),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            _Row(PhosphorIconsDuotone.fileText, 'Terms of service', '', onTap: () => context.push('/legal/terms')),
            const HairDivider(indent: 54),
            _Row(PhosphorIconsDuotone.lockSimple, 'Privacy policy', '', onTap: () => context.push('/legal/privacy')),
          ]),
        ),
      ]),
    );
  }
}

String acctFirst(WidgetRef ref) {
  final n = ref.read(accountProvider).firstName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  return n.isEmpty ? 'CRYSTAL' : n;
}
