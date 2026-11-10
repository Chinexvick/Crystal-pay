import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../services/models.dart';

final _tokFmt = NumberFormat('#,##0.####');
String tokens(double v) => _tokFmt.format(v);

/// A selectable method card (Naira / Crystal Cat).
class MethodCard extends StatelessWidget {
  const MethodCard({super.key, required this.icon, required this.title, required this.sub, required this.chips, required this.onTap, this.gradient = false});
  final PhosphorIconData icon;
  final String title, sub;
  final List<String> chips;
  final VoidCallback onTap;
  final bool gradient;
  @override
  Widget build(BuildContext context) {
    final fg = gradient ? Colors.white : C.ink;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient ? C.brandGradient : null,
          color: gradient ? null : C.surface,
          borderRadius: BorderRadius.circular(R.card + 4),
          border: gradient ? null : Border.all(color: C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconChip(icon, size: 48, bg: gradient ? Colors.white.withValues(alpha: .18) : C.tint, fg: gradient ? Colors.white : C.primary, iconSize: 26),
            const Spacer(),
            PhosphorIcon(PhosphorIconsBold.arrowRight, size: 18, color: gradient ? Colors.white : C.muted),
          ]),
          const Gap(16),
          Text(title, style: T.h3.copyWith(color: fg)),
          const Gap(4),
          Text(sub, style: T.small.copyWith(color: gradient ? Colors.white.withValues(alpha: .85) : C.muted, fontSize: 13)),
          const Gap(14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in chips) Tag(c, bg: gradient ? Colors.white.withValues(alpha: .18) : C.tint, fg: gradient ? Colors.white : C.primary),
          ]),
        ]),
      ),
    );
  }
}

/// Locked-rate summary with a live countdown.
class QuoteSummary extends StatefulWidget {
  const QuoteSummary({super.key, required this.quote, this.onExpired});
  final Quote quote;
  final VoidCallback? onExpired;
  @override
  State<QuoteSummary> createState() => _QuoteSummaryState();
}

class _QuoteSummaryState extends State<QuoteSummary> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.quote.expired) {
        _t?.cancel();
        widget.onExpired?.call();
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
    final q = widget.quote;
    final rem = q.remaining.isNegative ? Duration.zero : q.remaining;
    final mm = rem.inMinutes.toString().padLeft(2, '0');
    final ss = (rem.inSeconds % 60).toString().padLeft(2, '0');
    return AppCard(
      child: Column(children: [
        Row(children: [
          Text('You will send', style: T.small),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: rem.inMinutes < 2 ? C.goldTint : C.tint, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PhosphorIcon(PhosphorIconsBold.timer, size: 13, color: rem.inMinutes < 2 ? C.pending : C.primary),
              const HGap(4),
              Text('Rate locked $mm:$ss', style: T.caption.copyWith(color: rem.inMinutes < 2 ? C.pending : C.primary, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const Gap(6),
        Align(alignment: Alignment.centerLeft, child: Text('${tokens(q.tokens)} CCT', style: T.moneyOf(30, color: C.primary))),
        const Gap(8),
        const HairDivider(),
        KvRow('Rate', '1 CCT = ${money2(q.rate)}'),
        KvRow('Value of tokens', money2(q.grossNaira)),
        KvRow('Service fee (${(q.feeNaira / q.netNaira * 100).toStringAsFixed(1)}%)', money2(q.feeNaira)),
        const HairDivider(),
        KvRow('Credited to wallet', money2(q.netNaira), bold: true),
      ]),
    );
  }
}

/// Vertical progress for deposits.
class DepositStepper extends StatelessWidget {
  const DepositStepper({super.key, required this.session});
  final DepositSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final steps = <(String, String, DepositStatus)>[
      ('Waiting for your transfer', 'Send the exact amount to the address above', DepositStatus.awaiting),
      ('Transfer detected', 'We can see it on the network', DepositStatus.detected),
      ('Confirming on network', s.status == DepositStatus.confirming ? '${s.confirmations} of ${s.required} confirmations' : 'Waiting for ${s.required} confirmations', DepositStatus.confirming),
      ('Converting to Naira', 'At your locked rate', DepositStatus.converting),
      ('Wallet credited', 'Funds are ready to spend', DepositStatus.completed),
    ];
    final order = [for (final e in steps) e.$3];
    final curIdx = order.indexOf(s.status).clamp(0, order.length - 1);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      child: Column(children: [
        for (var i = 0; i < steps.length; i++)
          _Row(title: steps[i].$1, sub: steps[i].$2, done: i < curIdx || s.status == DepositStatus.completed, current: i == curIdx && s.status != DepositStatus.completed, last: i == steps.length - 1),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.sub, required this.done, required this.current, required this.last});
  final String title, sub;
  final bool done, current, last;
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: Column(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: done ? C.primary : C.surface, shape: BoxShape.circle, border: Border.all(color: done || current ? C.primary : C.border, width: 2)),
              child: done
                  ? const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 13, color: Colors.white))
                  : current
                      ? const Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 2.2, color: C.primary))
                      : null,
            ),
            if (!last) Expanded(child: Container(width: 2, color: done ? C.primary : C.border)),
          ]),
        ),
        const HGap(14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.title.copyWith(color: done || current ? C.ink : C.faint, fontSize: 14.5)),
              if (sub.isNotEmpty) Text(sub, style: T.small.copyWith(color: done || current ? C.muted : C.faint, fontSize: 12.5)),
            ]),
          ),
        ),
      ]),
    );
  }
}
