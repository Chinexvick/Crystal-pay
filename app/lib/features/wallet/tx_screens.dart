import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'tx_widgets.dart';

// ───────────────────────── Payment result ─────────────────────────

class PaymentResultScreen extends ConsumerStatefulWidget {
  const PaymentResultScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = ref.read(walletProvider.notifier).find(widget.id);
    if (tx == null) return const Scaffold(body: EmptyState(icon: PhosphorIconsDuotone.receipt, title: 'Receipt not found', message: 'This transaction is no longer available.'));
    final scale = CurvedAnimation(parent: _a, curve: Curves.elasticOut);
    final ring = CurvedAnimation(parent: _a, curve: const Interval(0, .7, curve: Curves.easeOut));
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.page, 36, Sp.page, 16),
              children: [
                Center(
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(alignment: Alignment.center, children: [
                      AnimatedBuilder(
                        animation: ring,
                        builder: (_, _) => Container(
                          width: 90 + 42 * ring.value,
                          height: 90 + 42 * ring.value,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: C.primary.withValues(alpha: .12 * (1 - ring.value * .4))),
                        ),
                      ),
                      ScaleTransition(
                        scale: scale,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: C.skyGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 44, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const Gap(20),
                Text(switch (tx.kind) { TxKind.topup => 'Wallet funded', TxKind.withdraw => 'Withdrawal on its way', TxKind.cctTopup => 'Wallet funded with CCT', TxKind.purchase => 'Order placed', _ => 'Payment successful' }, textAlign: TextAlign.center, style: T.h1),
                const Gap(6),
                Text(tx.subtitle, textAlign: TextAlign.center, style: T.small.copyWith(fontSize: 13.5)),
                const Gap(18),
                Text(money2(tx.amount), textAlign: TextAlign.center, style: T.moneyOf(38)),
                const Gap(24),
                if (tx.token != null) ...[_TokenCard(tx.token!), const Gap(16)],
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    KvRow('Product', tx.kind.label),
                    for (final e in tx.details.entries.take(5)) KvRow(e.key, e.value),
                    KvRow('Date', longDate(tx.date)),
                    KvRow('Reference', tx.id.toUpperCase()),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 16),
            child: Row(children: [
              Expanded(child: AppButton(label: 'Receipt', kind: BtnKind.soft, icon: PhosphorIconsBold.receipt, onPressed: () => context.pushReplacement('/tx/${tx.id}'))),
              const HGap(12),
              Expanded(child: AppButton(label: 'Done', onPressed: () => context.go('/home'))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard(this.token);
  final String token;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: C.deepGradient, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: [
          const PhosphorIcon(PhosphorIconsFill.lightning, size: 16, color: C.gold),
          const HGap(6),
          Text('Your electricity token', style: T.smallM.copyWith(color: Colors.white.withValues(alpha: .85))),
        ]),
        const Gap(10),
        Text(token, textAlign: TextAlign.center, style: T.moneyOf(24, w: FontWeight.w800, color: Colors.white).copyWith(letterSpacing: 1.5)),
        const Gap(14),
        AppButton(
          label: 'Copy token',
          icon: PhosphorIconsBold.copy,
          kind: BtnKind.onDark,
          small: true,
          expand: false,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: token.replaceAll(' ', '')));
            showToast(context, 'Token copied');
          },
        ),
      ]),
    );
  }
}

// ───────────────────────── Receipt / details ─────────────────────────

class TxDetailScreen extends ConsumerWidget {
  const TxDetailScreen({super.key, required this.id});
  final String id;

  void _repeat(BuildContext context, TxKind k) {
    final route = switch (k) {
      TxKind.airtime => '/bills/airtime',
      TxKind.data => '/bills/data',
      TxKind.electricity => '/bills/electricity',
      TxKind.tv => '/bills/tv',
      TxKind.betting => '/bills/betting',
      TxKind.internet => '/bills/internet',
      TxKind.international => '/bills/international',
      _ => '/bills',
    };
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(walletProvider).txs.where((t) => t.id == id).firstOrNull;
    if (tx == null) return Scaffold(appBar: const AppTopBar(title: 'Transaction'), body: const EmptyState(icon: PhosphorIconsDuotone.receipt, title: 'Not found', message: 'This transaction is no longer available.'));
    final failed = tx.status == Status.failed;
    final pending = tx.status == Status.pending;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Transaction Details'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Column(children: [
              IconChip(txIcon(tx.kind), size: 60, circle: true, bg: failed ? C.errorTint : (pending ? C.goldTint : C.tint), fg: failed ? C.error : (pending ? C.pending : C.primary), iconSize: 30),
              const Gap(14),
              Text(tx.title, style: T.small.copyWith(fontSize: 14)),
              const Gap(6),
              Text(signedMoney(tx.amount, credit: tx.credit), style: T.moneyOf(32, color: failed ? C.error : C.ink)),
              const Gap(10),
              StatusChip(tx.status),
              if (failed) ...[
                const Gap(16),
                InfoBanner(tx.details['Reason'] ?? 'This payment could not be completed. Any debit has been refunded to your wallet.', kind: BannerKind.error),
              ],
              if (pending) ...[
                const Gap(16),
                const InfoBanner('Your payment is held securely by Crystal Protect and will be released to the seller once you confirm delivery.'),
              ],
            ]),
          ),
          const Gap(14),
          if (tx.token != null) ...[_TokenCard(tx.token!), const Gap(14)],
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              KvRow('Transaction type', tx.kind.label),
              KvRow('Description', tx.subtitle),
              for (final e in tx.details.entries.where((e) => e.key != 'Reason')) KvRow(e.key, e.value),
              KvRow('Date', longDate(tx.date)),
              KvRow(
                'Reference',
                null,
                valueWidget: Pressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tx.id.toUpperCase()));
                    showToast(context, 'Reference copied');
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tx.id.toUpperCase(), style: T.bodyM),
                    const HGap(6),
                    const PhosphorIcon(PhosphorIconsRegular.copy, size: 15, color: C.primary),
                  ]),
                ),
              ),
            ]),
          ),
          const Gap(20),
          if (tx.kind.isBill && !failed) AppButton(label: 'Buy again', icon: PhosphorIconsBold.arrowClockwise, onPressed: () => _repeat(context, tx.kind)),
          if (failed) AppButton(label: 'Try again', icon: PhosphorIconsBold.arrowClockwise, onPressed: () => _repeat(context, tx.kind)),
          const Gap(12),
          Row(children: [
            Expanded(child: AppButton(label: 'Share', kind: BtnKind.soft, icon: PhosphorIconsBold.shareNetwork, onPressed: () => showToast(context, 'Receipt ready to share'))),
            const HGap(12),
            Expanded(child: AppButton(label: 'Report issue', kind: BtnKind.secondary, icon: PhosphorIconsBold.flag, onPressed: () => context.push('/help'))),
          ]),
        ],
      ),
    );
  }
}

// ───────────────────────── Transactions list ─────────────────────────

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.kind});
  final String? kind;
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TxKind? _kind;
  Status? _status;
  DateTime? _month;
  bool _billsOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'bills') {
      _billsOnly = true;
    } else if (widget.kind != null) {
      _kind = TxKind.values.where((k) => k.name == widget.kind).firstOrNull;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(walletProvider).txs;
    final months = {for (final t in all) DateTime(t.date.year, t.date.month)}.toList()..sort((a, b) => b.compareTo(a));
    final month = _month ?? (months.isEmpty ? DateTime.now() : months.first);
    final list = all.where((t) => (_kind == null || t.kind == _kind) && (!_billsOnly || t.kind.isBill) && (_status == null || t.status == _status) && t.date.year == month.year && t.date.month == month.month).toList()..sort((a, b) => b.date.compareTo(a.date));
    final inSum = list.where((t) => t.credit && t.status == Status.success).fold<num>(0, (a, t) => a + t.amount);
    final outSum = list.where((t) => !t.credit && t.status == Status.success).fold<num>(0, (a, t) => a + t.amount);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: _billsOnly ? 'Bill History' : 'Transaction History', actionLabel: 'Download', onAction: () => showToast(context, 'Statement will be sent to your email')),
      body: Column(children: [
        Container(
          color: C.surface,
          padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 14),
          child: Row(children: [
            Expanded(
              child: _FilterPill(
                label: _kind?.label ?? (_billsOnly ? 'Bills' : 'All Types'),
                active: _kind != null || _billsOnly,
                onTap: () async {
                  final k = await showAppSheet<Object>(
                    context,
                    builder: (ctx) => SheetFrame(
                      title: 'Transaction type',
                      child: Column(children: [
                        _Opt('All Types', _kind == null, () => Navigator.pop(ctx, 'all')),
                        for (final k in TxKind.values) _Opt(k.label, _kind == k, () => Navigator.pop(ctx, k)),
                      ]),
                    ),
                  );
                  if (k != null) {
                    setState(() {
                      _kind = k is TxKind ? k : null;
                      _billsOnly = false;
                    });
                  }
                },
              ),
            ),
            const HGap(12),
            Expanded(
              child: _FilterPill(
                label: switch (_status) { null => 'All Status', Status.success => 'Successful', Status.pending => 'Pending', Status.failed => 'Failed' },
                active: _status != null,
                onTap: () async {
                  final s = await showAppSheet<Object>(
                    context,
                    builder: (ctx) => SheetFrame(
                      title: 'Status',
                      child: Column(children: [
                        _Opt('All Status', _status == null, () => Navigator.pop(ctx, 'all')),
                        _Opt('Successful', _status == Status.success, () => Navigator.pop(ctx, Status.success)),
                        _Opt('Pending', _status == Status.pending, () => Navigator.pop(ctx, Status.pending)),
                        _Opt('Failed', _status == Status.failed, () => Navigator.pop(ctx, Status.failed)),
                      ]),
                    ),
                  );
                  if (s != null) setState(() => _status = s is Status ? s : null);
                },
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.page, 14, Sp.page, 32),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(children: [
                  Row(children: [
                    Pressable(
                      onTap: () async {
                        final m = await showAppSheet<DateTime>(
                          context,
                          builder: (ctx) => SheetFrame(title: 'Select Month', child: Column(children: [for (final m in months) _Opt(monthYear(m), m == month, () => Navigator.pop(ctx, m))])),
                        );
                        if (m != null) setState(() => _month = m);
                      },
                      child: Row(children: [
                        Text(monthYear(month), style: T.h2),
                        const HGap(6),
                        const PhosphorIcon(PhosphorIconsFill.caretDown, size: 14, color: C.ink),
                      ]),
                    ),
                    const Spacer(),
                    AppButton(label: 'Analysis', small: true, expand: false, onPressed: () => _analysis(context, list)),
                  ]),
                  const Gap(8),
                  Row(children: [
                    Text('In: ', style: T.small),
                    Text(money2(inSum), style: T.money.copyWith(fontSize: 13.5, color: C.primary)),
                    const HGap(20),
                    Text('Out: ', style: T.small),
                    Text(money2(outSum), style: T.money.copyWith(fontSize: 13.5)),
                  ]),
                  const Gap(12),
                  if (list.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: EmptyState(icon: PhosphorIconsDuotone.receipt, title: 'No transactions', message: 'Nothing matches these filters for this month.'))
                  else
                    for (var i = 0; i < list.length; i++) TxRow(list[i], last: i == list.length - 1),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  void _analysis(BuildContext context, List<Tx> list) {
    final spend = <TxKind, num>{};
    for (final t in list.where((t) => !t.credit && t.status == Status.success)) {
      spend[t.kind] = (spend[t.kind] ?? 0) + t.amount;
    }
    final total = spend.values.fold<num>(0, (a, b) => a + b);
    final rows = spend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetFrame(
        title: 'Spending analysis',
        child: rows.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: EmptyState(icon: PhosphorIconsDuotone.chartBar, title: 'No spending yet', message: 'Make a payment and your breakdown will appear here.'))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(money2(total), style: T.moneyOf(30)),
                Text('Total spent this month', style: T.small),
                const Gap(18),
                for (final e in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(children: [
                      Row(children: [
                        Text(e.key.label, style: T.title),
                        const Spacer(),
                        Text(money2(e.value), style: T.money.copyWith(fontSize: 14)),
                      ]),
                      const Gap(8),
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (e.value / total).toDouble(), minHeight: 8, backgroundColor: C.tint, color: C.primary)),
                    ]),
                  ),
              ]),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onTap, this.active = false});
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: active ? C.tint : C.bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(color: active ? C.primary : C.ink))),
          PhosphorIcon(PhosphorIconsFill.caretDown, size: 13, color: active ? C.primary : C.muted),
        ]),
      ),
    );
  }
}

class _Opt extends StatelessWidget {
  const _Opt(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
        child: Row(children: [
          Expanded(child: Text(label, style: T.title.copyWith(color: selected ? C.primary : C.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
          if (selected) const PhosphorIcon(PhosphorIconsBold.check, size: 18, color: C.primary),
        ]),
      ),
    );
  }
}
