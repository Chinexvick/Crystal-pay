import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/state.dart';

class _Cat {
  const _Cat(this.label, this.icon, this.route, this.bg);
  final String label;
  final String icon;
  final String route;
  final Color bg;
}

const _cats = <_Cat>[
  _Cat('Electricity', 'electricity', '/bills/electricity', C.tint),
  _Cat('Data', 'data', '/bills/data', C.blueTint),
  _Cat('Cable TV', 'tv', '/bills/tv', C.greenTint),
  _Cat('Airtime', 'airtime', '/bills/airtime', C.greenTint),
  _Cat('Internet', 'internet', '/bills/internet', C.blueTint),
  _Cat('Betting', 'betting', '/bills/betting', C.tint),
  _Cat('Intl Airtime', 'intl', '/bills/international', C.blueTint),
  _Cat('Saved', 'beneficiaries', '/beneficiaries', C.tint),
];

/// Bills tab, modelled on the approved "Bill Categories" design.
class BillsHubScreen extends ConsumerWidget {
  const BillsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(walletProvider).txs.where((t) => t.kind.isBill).take(4).toList();
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          TabHeader(
            title: 'Bills',
            subtitle: 'Airtime, data, power and TV in seconds',
            actions: [HeaderIcon(icon: PhosphorIconsRegular.clockCounterClockwise, onTap: () => context.push('/transactions?kind=bills'))],
          ),
          const Gap(22),
          SectionHeader('Bill Categories', action: 'See All', onAction: () => _allSheet(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.page),
            child: LayoutBuilder(builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap * 3) / 4;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final cat in _cats) SizedBox(width: w, height: w * 1.08, child: _Tile(cat)),
              ]);
            }),
          ),
          const Gap(22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.page),
            child: PromoBanner(
              title: 'Secure Payments',
              subtitle: 'PIN-protected and fully encrypted.',
              image: 'assets/illustrations/shield.webp',
              height: 120,
              imageWidthFactor: .36,
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .3))),
                child: const Center(child: PhosphorIcon(PhosphorIconsFill.lockKey, size: 22, color: Colors.white)),
              ),
              onTap: () => context.push('/settings/security'),
            ),
          ),
          const Gap(26),
          SectionHeader('Recent Bills', action: 'View History', onAction: () => context.push('/transactions?kind=bills')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.page),
            child: recent.isEmpty
                ? const InfoBanner('Your paid bills will show here.')
                : AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0) const HairDivider(indent: 56),
                        _RecentBill(recent[i]),
                      ],
                    ]),
                  ),
          ),
          const Gap(18),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.page), child: _TopUpBar(onTap: () => context.push('/wallet/add'))),
        ],
      ),
    );
  }

  void _allSheet(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetFrame(
        title: 'All Bills',
        child: Column(children: [
          for (final c in _cats)
            Pressable(
              onTap: () {
                Navigator.pop(ctx);
                context.push(c.route);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  IconTile(c.icon, size: 44, bg: c.bg),
                  const HGap(14),
                  Expanded(child: Text(c.label, style: T.title)),
                  const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.c);
  final _Cat c;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(c.route),
      scale: .95,
      child: Container(
        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(R.tile), border: Border.all(color: Colors.white, width: 1.5)),
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Column(children: [
          Expanded(child: Icon3D(c.icon, size: 44)),
          const Gap(4),
          Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

String _billIcon(TxKind k) => switch (k) {
      TxKind.airtime => 'airtime',
      TxKind.data => 'data',
      TxKind.electricity => 'electricity',
      TxKind.tv => 'tv',
      TxKind.betting => 'betting',
      TxKind.internet => 'internet',
      TxKind.international => 'intl',
      _ => 'bills',
    };

class _RecentBill extends StatelessWidget {
  const _RecentBill(this.t);
  final Tx t;
  @override
  Widget build(BuildContext context) {
    final provider = t.subtitle;
    return Pressable(
      onTap: () => context.push('/tx/${t.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: C.tint2, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon3D(_billIcon(t.kind), size: 28),
          ),
          const HGap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.kind == TxKind.data ? 'Data Subscription' : (t.kind == TxKind.tv ? 'Cable TV' : '${t.kind.label} Bill'), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14.5)),
              Text(provider, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
            ]),
          ),
          const HGap(8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(t.amount), style: T.moneyOf(14.5)),
            const Gap(4),
            StatusChip(t.status, label: t.status == Status.success ? 'Paid' : null),
          ]),
          const HGap(6),
          const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
        ]),
      ),
    );
  }
}

class _TopUpBar extends StatelessWidget {
  const _TopUpBar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(gradient: C.violetGradient, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
            child: const Center(child: PhosphorIcon(PhosphorIconsRegular.creditCard, size: 24, color: Colors.white)),
          ),
          const HGap(14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Top Up Wallet', style: T.title.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const Gap(2),
              Text('Fund your wallet for seamless payments', style: T.small.copyWith(color: Colors.white.withValues(alpha: .85), fontSize: 12)),
            ]),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Center(child: PhosphorIcon(PhosphorIconsBold.arrowRight, size: 18, color: C.primaryDark)),
          ),
        ]),
      ),
    );
  }
}
