import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';

PhosphorIconData txIcon(TxKind k) => switch (k) {
      TxKind.airtime => PhosphorIconsDuotone.deviceMobile,
      TxKind.data => PhosphorIconsDuotone.wifiHigh,
      TxKind.electricity => PhosphorIconsDuotone.lightning,
      TxKind.tv => PhosphorIconsDuotone.television,
      TxKind.betting => PhosphorIconsDuotone.soccerBall,
      TxKind.internet => PhosphorIconsDuotone.network,
      TxKind.international => PhosphorIconsDuotone.globeHemisphereWest,
      TxKind.topup => PhosphorIconsDuotone.arrowDownLeft,
      TxKind.withdraw => PhosphorIconsDuotone.arrowUpRight,
      TxKind.purchase => PhosphorIconsDuotone.shoppingBag,
      TxKind.sale => PhosphorIconsDuotone.tag,
      TxKind.refund => PhosphorIconsDuotone.arrowCounterClockwise,
      TxKind.subscription => PhosphorIconsDuotone.storefront,
      TxKind.transfer => PhosphorIconsDuotone.paperPlaneTilt,
      TxKind.cctTopup => PhosphorIconsDuotone.coins,
    };

/// One transaction line (icon · title · date · amount · status).
class TxRow extends StatelessWidget {
  const TxRow(this.t, {super.key, this.last = false});
  final Tx t;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final failed = t.status == Status.failed;
    return Pressable(
      onTap: () => context.push('/tx/${t.id}'),
      scale: .99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          IconChip(txIcon(t.kind), size: 44, circle: true, bg: failed ? C.errorTint : C.tint, fg: failed ? C.error : C.primary, iconSize: 22),
          const HGap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: T.title),
              const Gap(3),
              Text(txDate(t.date), style: T.small.copyWith(fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(signedMoney(t.amount, credit: t.credit), style: T.money.copyWith(color: t.credit ? C.primary : C.ink, fontSize: 15)),
            const Gap(4),
            StatusChip(t.status),
          ]),
        ]),
      ),
    );
  }
}
