import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/contacts.dart';
import '../../core/security/pin_guard.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/state.dart';

// ───────────────────────── Scaffold & promo ─────────────────────────

/// Shared chrome for every bill screen: top bar with History, grey canvas.
class BillScaffold extends StatelessWidget {
  const BillScaffold({super.key, required this.title, required this.kind, required this.child, this.bottom});
  final String title;
  final TxKind kind;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: title, actionLabel: 'History', onAction: () => context.push('/transactions?kind=${kind.name}')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: child,
      ),
      bottomNavigationBar: bottom,
    );
  }
}

class PromoStrip extends StatelessWidget {
  const PromoStrip({super.key, required this.title, required this.sub, this.icon = PhosphorIconsDuotone.sparkle, this.gradient = C.deepGradient});
  final String title;
  final String sub;
  final PhosphorIconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.title.copyWith(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
            const Gap(3),
            Text(sub, style: T.small.copyWith(color: Colors.white.withValues(alpha: .85), fontSize: 12)),
          ]),
        ),
        const HGap(10),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
          child: Center(child: PhosphorIcon(icon, size: 24, color: Colors.white)),
        ),
      ]),
    );
  }
}

// ───────────────────────── Phone / network field ─────────────────────────

/// Network selector + phone number input + beneficiaries shortcut.
class PhoneCard extends ConsumerWidget {
  const PhoneCard({super.key, required this.controller, required this.networkId, required this.onNetwork, required this.onChanged, required this.kind, this.error});
  final TextEditingController controller;
  final String networkId;
  final ValueChanged<String> onNetwork;
  final ValueChanged<String> onChanged;
  final TxKind kind;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = networkById(networkId);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pressable(
            onTap: () async {
              FocusScope.of(context).unfocus();
              final id = await showNetworkSheet(context, networkId);
              if (id != null) onNetwork(id);
            },
            child: Row(children: [
              ProviderLogo(asset: net.asset, name: net.name, size: 40),
              const HGap(4),
              const PhosphorIcon(PhosphorIconsFill.caretDown, size: 14, color: C.faint),
            ]),
          ),
          Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12), color: C.border),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              onChanged: onChanged,
              cursorColor: C.primary,
              style: T.moneyOf(21, w: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '08012345678',
                hintStyle: T.moneyOf(20, w: FontWeight.w500, color: C.border),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Pressable(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Padding(padding: EdgeInsets.all(6), child: PhosphorIcon(PhosphorIconsFill.xCircle, size: 18, color: C.faint)),
            ),
          Pressable(
            onTap: () async {
              FocusScope.of(context).unfocus();
              final n = await pickPhoneContact(context);
              if (n != null) {
                controller.text = n;
                final d = detectNetwork(n);
                if (d != null) onNetwork(d);
                onChanged(n);
              }
            },
            child: const IconChip(PhosphorIconsDuotone.addressBook, size: 38, circle: true, iconSize: 20),
          ),
        ]),
        const Gap(10),
        Align(
          alignment: Alignment.centerRight,
          child: Pressable(
            onTap: () async {
              FocusScope.of(context).unfocus();
              final b = await showBeneficiarySheet(context, kind: kind);
              if (b != null) {
                controller.text = b.value;
                if (b.billerId != null) onNetwork(b.billerId!);
                onChanged(b.value);
              }
            },
            child: Text('Saved beneficiaries', style: T.label.copyWith(color: C.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
        if (error != null) ...[
          const Gap(8),
          Row(children: [
            const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 14, color: C.error),
            const HGap(6),
            Text(error!, style: T.small.copyWith(color: C.error, fontSize: 12)),
          ]),
        ],
      ]),
    );
  }
}

Future<String?> showNetworkSheet(BuildContext context, String selected) {
  return showAppSheet<String>(
    context,
    builder: (ctx) => SheetFrame(
      title: 'Select network',
      child: Column(children: [
        for (final n in networks)
          _RadioRow(
            leading: ProviderLogo(asset: n.asset, name: n.name, size: 44),
            title: n.name,
            selected: n.id == selected,
            onTap: () => Navigator.pop(ctx, n.id),
          ),
      ]),
    ),
  );
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.leading, required this.title, required this.selected, required this.onTap, this.badge});
  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
        child: Row(children: [
          leading,
          const HGap(14),
          Flexible(child: Text(title, style: T.title.copyWith(fontSize: 15.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (badge != null) ...[const HGap(8), badge!],
          const Spacer(),
          RadioDot(selected: selected),
        ]),
      ),
    );
  }
}

class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected, this.size = 24});
  final bool selected;
  final double size;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? C.primary : Colors.transparent,
        border: Border.all(color: selected ? C.primary : C.border, width: 1.8),
      ),
      child: selected ? Center(child: PhosphorIcon(PhosphorIconsBold.check, size: size * .58, color: Colors.white)) : null,
    );
  }
}

/// Generic "Select provider" sheet with radio list (electricity, betting more, etc.).
Future<Biller?> showProviderSheet(BuildContext context, {required String title, required List<Biller> items, String? selectedId}) {
  return showAppSheet<Biller>(
    context,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .78),
      child: SheetFrame(
        title: title,
        child: Column(children: [
          for (final b in items)
            _RadioRow(
              leading: ProviderLogo(asset: b.asset, name: b.name, size: 44, color: b.color),
              title: b.name,
              selected: b.id == selectedId,
              badge: b.isNew ? const Tag('NEW', bg: C.errorTint, fg: C.error) : null,
              onTap: () => Navigator.pop(ctx, b),
            ),
        ]),
      ),
    ),
  );
}

Future<Beneficiary?> showBeneficiarySheet(BuildContext context, {required TxKind kind}) {
  return showAppSheet<Beneficiary>(
    context,
    builder: (ctx) => Consumer(builder: (context, ref, _) {
      final all = ref.watch(beneficiariesProvider).where((b) => b.kind == kind).toList();
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
        child: SheetFrame(
          title: 'Beneficiaries',
          child: all.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: EmptyState(icon: PhosphorIconsDuotone.addressBook, title: 'No saved beneficiaries', message: 'Tick “Save as beneficiary” when you pay and they will show up here.'))
              : Column(children: [
                  for (final b in all)
                    Pressable(
                      onTap: () => Navigator.pop(ctx, b),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
                        child: Row(children: [
                          Avatar(name: b.name, size: 42),
                          const HGap(14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(b.name, style: T.title),
                              const Gap(2),
                              Text(kind == TxKind.airtime || kind == TxKind.data ? phoneSpaced(b.value) : b.value, style: T.small),
                            ]),
                          ),
                          if (billerFor(b.billerId) != null) ProviderLogo(asset: billerFor(b.billerId)!.asset, name: billerFor(b.billerId)!.name, size: 30, color: billerFor(b.billerId)!.color),
                        ]),
                      ),
                    ),
                ]),
        ),
      );
    }),
  );
}

// ───────────────────────── Amount card ─────────────────────────

/// Quick-pick amounts + free amount + Pay button (airtime / electricity / betting).
class AmountCard extends StatelessWidget {
  const AmountCard({super.key, this.title, required this.quick, required this.controller, required this.onChanged, required this.onPay, required this.min, required this.max, this.selected, this.subtitleOf, this.hint, this.payEnabled = true, this.showGrid = true, this.error});
  final String? title;
  final List<int> quick;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onPay;
  final int min;
  final int max;
  final int? selected;
  final String Function(int)? subtitleOf;
  final String? hint;
  final bool payEnabled;
  final bool showGrid;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final v = int.tryParse(controller.text) ?? 0;
    final valid = v >= min && v <= max && payEnabled;
    final msg = controller.text.isNotEmpty && (v < min || v > max) ? 'Enter ${money(min)} – ${money(max)}' : error;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[Text(title!, style: T.h3), const Gap(14)],
        if (showGrid && quick.isNotEmpty) ...[
          QuickAmountGrid(
            amounts: quick,
            selected: selected,
            subtitleOf: subtitleOf,
            onSelect: (a) {
              controller.text = '$a';
              controller.selection = TextSelection.collapsed(offset: controller.text.length);
              onChanged('$a');
            },
          ),
          const Gap(16),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: AmountField(controller: controller, hint: hint ?? '${money(min)} – ${money(max)}', onChanged: onChanged, error: msg)),
          const HGap(12),
          SizedBox(width: 110, child: AppButton(label: 'Pay', onPressed: valid ? onPay : null, height: 56)),
        ]),
      ]),
    );
  }
}

// ───────────────────────── Payment flow ─────────────────────────

class BillRequest {
  const BillRequest({
    required this.kind,
    required this.productName,
    required this.rows,
    required this.amount,
    required this.subtitle,
    this.provider,
    this.cashback = 0,
    this.details = const {},
    this.token,
    this.discount = 0,
    this.beneficiary,
  });
  final TxKind kind;
  final String productName;
  final Biller? provider;
  final List<(String, String)> rows;
  final num amount; // what the wallet is charged
  final num cashback;
  final num discount;
  final String subtitle;
  final Map<String, String> details;
  final String? token;
  final Beneficiary? beneficiary;
}

/// Confirm → PIN → processing → result. Returns once the flow has finished.
Future<void> startBillPayment(BuildContext context, WidgetRef ref, BillRequest r) async {
  final confirmed = await showAppSheet<bool>(context, builder: (_) => ConfirmSheet(r));
  if (confirmed != true || !context.mounted) return;
  final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: r.amount));
  if (pin != true || !context.mounted) return;

  showDialog<void>(context: context, barrierDismissible: false, barrierColor: C.scrim, builder: (_) => const ProcessingDialog());
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  try {
    final tx = ref.read(walletProvider.notifier).pay(
          kind: r.kind,
          title: r.kind.label,
          subtitle: r.subtitle,
          amount: r.amount,
          details: {...r.details, for (final e in r.rows) if (e.$1 != 'Amount' && !r.details.containsKey(e.$1) && e.$1 != 'Product Name') e.$1: e.$2},
          token: r.token,
        );
    if (r.cashback > 0) ref.read(walletProvider.notifier).addCashback(r.cashback);
    if (r.beneficiary != null) ref.read(beneficiariesProvider.notifier).add(r.beneficiary!);
    if (context.mounted) context.push('/pay/${tx.id}');
  } on InsufficientFunds {
    if (context.mounted) showToast(context, 'Insufficient wallet balance', error: true);
  }
}

class ConfirmSheet extends ConsumerWidget {
  const ConfirmSheet(this.r, {super.key});
  final BillRequest r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bal = ref.watch(walletProvider).balance;
    final short = r.amount > bal;
    return SheetFrame(
      showClose: true,
      title: ' ',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Text(money2(r.amount), style: T.moneyOf(38))),
        const Gap(22),
        AppCard(
          color: C.bg,
          borderColor: null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            KvRow(
              'Product Name',
              null,
              valueWidget: Row(mainAxisSize: MainAxisSize.min, children: [
                if (r.provider != null) ...[ProviderLogo(asset: r.provider!.asset, name: r.provider!.name, size: 24, color: r.provider!.color), const HGap(8)],
                Flexible(child: Text(r.productName, style: T.bodyM, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            for (final (k, v) in r.rows) KvRow(k, v),
            if (r.discount > 0) KvRow('Voucher', '-${money2(r.discount)}', valueColor: C.primary),
            if (r.cashback > 0) KvRow('Cashback', '+${money2(r.cashback)}', valueColor: C.primary, bold: true),
          ]),
        ),
        const Gap(18),
        Row(children: [
          Text('Payment Method', style: T.label.copyWith(color: C.muted)),
        ]),
        const Gap(10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          borderColor: short ? C.error : C.primary.withValues(alpha: .25),
          color: short ? C.errorTint.withValues(alpha: .5) : C.tint2,
          child: Column(children: [
            Row(children: [
              const IconChip(PhosphorIconsDuotone.wallet, size: 36, circle: true, iconSize: 19),
              const HGap(12),
              Expanded(child: Text.rich(TextSpan(children: [TextSpan(text: 'Wallet ', style: T.title), TextSpan(text: '(${money2(bal)})', style: T.small.copyWith(fontSize: 13))]))),
              if (!short) const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 24, color: C.primary),
            ]),
            const Gap(12),
            CustomPaint(painter: _DashPainter(), size: const Size(double.infinity, 1)),
            const Gap(12),
            Row(children: [
              Text('Wallet debit', style: T.small.copyWith(fontSize: 13.5)),
              const Spacer(),
              Text('-${money2(r.amount)}', style: T.money.copyWith(color: short ? C.error : C.ink)),
            ]),
          ]),
        ),
        if (short) ...[
          const Gap(12),
          InfoBanner('Your wallet balance is too low for this payment. Add ${money2(r.amount - bal)} to continue.', kind: BannerKind.error),
        ],
        const Gap(20),
        if (short)
          AppButton(
            label: 'Add Money',
            icon: PhosphorIconsBold.plus,
            onPressed: () {
              Navigator.pop(context, false);
              context.push('/wallet/add');
            },
          )
        else
          AppButton(label: 'Pay ${money2(r.amount)}', onPressed: () => Navigator.pop(context, true)),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.border
      ..strokeWidth = 1.4;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), p);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class PinSheet extends ConsumerStatefulWidget {
  const PinSheet({super.key, required this.amount, this.title = 'Enter transaction PIN', this.subtitle});
  final num amount;
  final String title;
  final String? subtitle;
  @override
  ConsumerState<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<PinSheet> {
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Demo rule: any 4 digits work, except 0000 which shows the error state.
  /// Production: send the PIN to the server over TLS. Never store it locally.
  void _check(String pin) {
    final guard = ref.read(pinGuardProvider.notifier);
    if (ref.read(pinGuardProvider).locked) return;
    if (pin == '0000') {
      guard.fail();
      final g = ref.read(pinGuardProvider);
      setState(() => _error = g.locked ? 'Too many attempts' : 'Incorrect PIN · ${g.attemptsLeft} attempts left');
      HapticFeedback.heavyImpact();
      return;
    }
    guard.success();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(pinGuardProvider);
    final locked = g.locked;
    final secs = g.remaining.inSeconds + 1;
    return SheetFrame(
      title: widget.title,
      child: Column(children: [
        Text(widget.subtitle ?? 'Confirm payment of ${money2(widget.amount)}', style: T.small.copyWith(fontSize: 13.5), textAlign: TextAlign.center),
        const Gap(26),
        if (locked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              const PhosphorIcon(PhosphorIconsDuotone.lockKey, size: 44, color: C.error),
              const Gap(12),
              Text('PIN locked', style: T.h3),
              const Gap(4),
              Text('Too many wrong attempts. Try again in 0:${secs.toString().padLeft(2, '0')}', style: T.small.copyWith(fontSize: 13.5), textAlign: TextAlign.center),
            ]),
          )
        else
          PinEntry(onComplete: _check, error: _error),
        const Gap(6),
        TextLink('Forgot PIN?', onTap: () {
          Navigator.pop(context, false);
          context.push('/settings/security');
        }, trailing: false),
        const Gap(4),
      ]),
    );
  }
}

class ProcessingDialog extends StatelessWidget {
  const ProcessingDialog({super.key});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3.6, color: C.primary, strokeCap: StrokeCap.round)),
            const Gap(18),
            Text('Processing…', style: T.title.copyWith(decoration: TextDecoration.none)),
            const Gap(4),
            Text('Please don’t close the app', style: T.small.copyWith(fontSize: 12, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

/// Underline tab strip (HOT / Daily / …).
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({super.key, required this.items, required this.index, required this.onChanged});
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const HGap(22),
        itemBuilder: (_, i) {
          final sel = i == index;
          return Pressable(
            onTap: () => onChanged(i),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(items[i], style: T.title.copyWith(color: sel ? C.primary : C.muted, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
              const Gap(6),
              AnimatedContainer(duration: const Duration(milliseconds: 180), width: sel ? 22 : 0, height: 3, decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(2))),
            ]),
          );
        },
      ),
    );
  }
}

/// Re-usable "verified account" chip row under meter/smartcard/ID inputs.
class VerifiedName extends StatelessWidget {
  const VerifiedName(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 18, color: C.primary),
      const HGap(8),
      Expanded(child: Text(name, style: T.title.copyWith(color: C.primary, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

/// Checkbox row "Save as beneficiary".
class SaveBeneficiaryRow extends StatelessWidget {
  const SaveBeneficiaryRow({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: value ? C.primary : Colors.transparent, borderRadius: BorderRadius.circular(7), border: Border.all(color: value ? C.primary : C.border, width: 1.8)),
          child: value ? const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 13, color: Colors.white)) : null,
        ),
        const HGap(10),
        Text('Save as beneficiary', style: T.smallM.copyWith(color: C.ink)),
      ]),
    );
  }
}
