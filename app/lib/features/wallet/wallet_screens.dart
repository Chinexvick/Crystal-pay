import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../data/account.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'tx_widgets.dart';

// ───────────────────────── Wallet ─────────────────────────

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    final verified = ref.watch(accountProvider).idVerified;
    final held = ref.watch(ordersProvider).where((o) => o.role == OrderRole.buying && (o.stage == OrderStage.paid || o.stage == OrderStage.shipped || o.stage == OrderStage.delivered)).fold<int>(0, (a, o) => a + o.total);
    final recent = w.txs.take(5).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Wallet', bg: C.bg, actions: [RoundIconButton(icon: PhosphorIconsRegular.headset, onTap: () => context.push('/help'), size: 40)]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 6, Sp.page, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: C.deepGradient, borderRadius: BorderRadius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(right: -70, top: -80, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
              Positioned(left: -50, bottom: -110, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .05)))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Available Balance', style: T.smallM.copyWith(color: Colors.white.withValues(alpha: .82))),
                  const HGap(8),
                  Pressable(
                    onTap: () => ref.read(balanceHiddenProvider.notifier).toggle(),
                    child: PhosphorIcon(hidden ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 18, color: Colors.white.withValues(alpha: .85)),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: verified ? null : () => context.push('/settings/verify-id'),
                    child: Tag(verified ? 'Verified' : 'Verify ID', bg: Colors.white.withValues(alpha: .15), fg: Colors.white, icon: verified ? PhosphorIconsFill.sealCheck : PhosphorIconsFill.warningCircle),
                  ),
                ]),
                const Gap(10),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(hidden ? '₦ ••••••••' : money2(w.balance), style: T.moneyOf(36, color: Colors.white))),
                const Gap(14),
                Pressable(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: '9000012345'));
                    showToast(context, 'Account number copied');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Wema Bank · 9051 482 770', style: T.smallM.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const HGap(8),
                      PhosphorIcon(PhosphorIconsRegular.copy, size: 15, color: Colors.white.withValues(alpha: .9)),
                    ]),
                  ),
                ),
                const Gap(20),
                Row(children: [
                  Expanded(child: _WalletAction(PhosphorIconsBold.plus, 'Add Money', () => context.push('/wallet/add'))),
                  const HGap(10),
                  Expanded(child: _WalletAction(PhosphorIconsBold.paperPlaneTilt, 'Send', () => context.push('/send'))),
                  const HGap(10),
                  Expanded(child: _WalletAction(PhosphorIconsBold.arrowUpRight, 'Withdraw', () => context.push('/wallet/withdraw'))),
                ]),
              ]),
            ]),
          ),
          const Gap(14),
          Row(children: [
            Expanded(child: _Stat(icon: 'security', label: 'Held in Crystal Protect', value: money2(held))),
            const HGap(12),
            Expanded(child: _Stat(icon: 'gift', label: 'Cashback earned', value: money2(w.cashback))),
          ]),
          const Gap(14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              _MenuRow('chart', 'Transaction History', 'Payments, top-ups and sales', () => context.push('/transactions')),
              _MenuRow('beneficiaries', 'Saved Beneficiaries', 'Numbers, meters and smartcards', () => context.push('/beneficiaries')),
              _MenuRow('bills', 'Vouchers', '1 voucher available', () => showToast(context, 'You have 1 voucher: ₦20 off electricity'), last: true),
            ]),
          ),
          const Gap(24),
          SectionHeader('Recent Activity', action: 'See All', onAction: () => context.push('/transactions'), padding: const EdgeInsets.only(bottom: 10)),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [for (var i = 0; i < recent.length; i++) TxRow(recent[i], last: i == recent.length - 1)]),
          ),
        ],
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction(this.icon, this.label, this.onTap);
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: PhosphorIcon(icon, size: 17, color: C.primaryDark))),
          const Gap(8),
          Text(label, style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconTile(icon, size: 40, bg: C.tint2),
        const Gap(12),
        Text(value, style: T.moneyOf(16, w: FontWeight.w800)),
        const Gap(3),
        Text(label, style: T.small.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.title, this.sub, this.onTap, {this.last = false});
  final String icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool last;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.border))),
        child: Row(children: [
          IconTile(icon, size: 44, bg: C.tint2),
          const HGap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.title),
              const Gap(2),
              Text(sub, style: T.small.copyWith(fontSize: 12)),
            ]),
          ),
          const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
        ]),
      ),
    );
  }
}

// ───────────────────────── Add money ─────────────────────────
