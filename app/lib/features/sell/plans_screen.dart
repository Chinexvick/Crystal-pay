import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/account.dart';
import '../../data/models.dart';
import '../../data/plans.dart';
import '../../data/state.dart';
import '../bills/bill_common.dart' show PinSheet;

final _dateFmt = DateFormat('d MMM yyyy');

/// Listings the seller currently has live.
final activeListingCountProvider = Provider<int>((ref) => ref.watch(myListingsProvider).where((l) => l.status == ListingStatus.active).length);

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acct = ref.watch(accountProvider);
    final used = ref.watch(activeListingCountProvider);
    final cur = acct.planActive ? planById(acct.plan!) : null;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Seller Plans'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        if (cur != null)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${cur.name} plan', style: T.h3),
                const HGap(8),
                const Tag('Active'),
                const Spacer(),
                Text('${money(cur.price)}/mo', style: T.title),
              ]),
              const Gap(4),
              Text('Renews ${_dateFmt.format(acct.planRenews!)}', style: T.small),
              const Gap(14),
              Row(children: [
                Text('Listings used', style: T.small),
                const Spacer(),
                Text('$used of ${cur.listingLimit}', style: T.label),
              ]),
              const Gap(8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: (used / cur.listingLimit).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: C.tint, color: used >= cur.listingLimit ? C.error : C.primary),
              ),
            ]),
          )
        else
          const InfoBanner('You need an active seller plan to post items. Pick one below. Buying and bill payments stay free.', kind: BannerKind.warning),
        const Gap(18),
        for (final p in plans) ...[
          _PlanCard(plan: p, current: cur?.id == p.id, hasPlan: cur != null, onChoose: () => _choose(context, ref, p, used)),
          const Gap(14),
        ],
        Text('Plans bill every $kPlanPeriodDays days from your wallet. Listings that sell or that you remove free up space straight away. If your plan lapses, your items are hidden from buyers until you renew.', style: T.small),
      ]),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, Plan p, int used) async {
    final acct = ref.read(accountProvider);
    if (acct.planActive && acct.plan == p.id) return;
    if (used > p.listingLimit) {
      showToast(context, 'You have $used live listings. Remove ${used - p.listingLimit} to move to ${p.name}.', error: true);
      return;
    }
    final ok = await showAppSheet<bool>(context, builder: (_) => _SubscribeSheet(plan: p));
    if (ok != true || !context.mounted) return;
    final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: p.price, title: 'Confirm with your PIN', subtitle: '${p.name} plan · ${money(p.price)}'));
    if (pin != true || !context.mounted) return;
    try {
      ref.read(walletProvider.notifier).pay(
            kind: TxKind.subscription,
            title: '${p.name} seller plan',
            subtitle: '30 days',
            amount: p.price,
            details: {'Plan': p.name, 'Listings': '${p.listingLimit}', 'Period': '$kPlanPeriodDays days'},
          );
      ref.read(accountProvider.notifier).subscribe(p.id);
      showToast(context, '${p.name} plan is active', icon: PhosphorIconsFill.checkCircle);
      if (context.canPop()) context.pop();
    } on InsufficientFunds {
      showToast(context, 'Not enough balance. Add money and try again.', error: true);
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.current, required this.hasPlan, required this.onChoose});
  final Plan plan;
  final bool current, hasPlan;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final label = current ? 'Current plan' : (hasPlan ? 'Switch to ${plan.name}' : 'Choose ${plan.name}');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.card),
        border: Border.all(color: plan.popular || current ? C.primary : C.border, width: plan.popular || current ? 1.6 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(plan.name, style: T.h2),
          const HGap(8),
          if (plan.popular) const Tag('Most popular'),
        ]),
        const Gap(2),
        Text(plan.tagline, style: T.small),
        const Gap(12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(plan.price), style: T.moneyOf(28)),
          const HGap(4),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('/ month', style: T.small)),
        ]),
        const Gap(14),
        const HairDivider(),
        const Gap(12),
        for (final f in plan.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: PhosphorIcon(PhosphorIconsBold.check, size: 14, color: C.primary)),
              const HGap(10),
              Expanded(child: Text(f, style: T.body.copyWith(fontSize: 14, height: 1.35))),
            ]),
          ),
        const Gap(8),
        AppButton(label: label, kind: plan.popular && !current ? BtnKind.primary : BtnKind.secondary, onPressed: current ? null : onChoose),
      ]),
    );
  }
}

class _SubscribeSheet extends ConsumerWidget {
  const _SubscribeSheet({required this.plan});
  final Plan plan;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bal = ref.watch(walletProvider).balance;
    final enough = bal >= plan.price;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Subscribe to ${plan.name}', style: T.h2),
        const Gap(12),
        KvRow('Plan', '${plan.name} · ${plan.listingLimit} listings'),
        KvRow('Billing', 'Every $kPlanPeriodDays days'),
        KvRow('Paid from', 'Wallet · ${money(bal)}'),
        KvRow('Amount', money(plan.price), bold: true),
        const Gap(14),
        if (!enough) ...[
          InfoBanner('Your wallet is ${money(plan.price - bal)} short.', kind: BannerKind.warning, action: 'Add money', onAction: () {
            Navigator.of(context).pop(false);
            context.push('/wallet/add');
          }),
          const Gap(12),
        ],
        AppButton(label: 'Pay ${money(plan.price)}', onPressed: enough ? () => Navigator.of(context).pop(true) : null),
      ]),
    );
  }
}

/// Shown in place of the post form when the seller cannot post yet.
class PlanBlock extends StatelessWidget {
  const PlanBlock({super.key, required this.noPlan, required this.limit, this.planName});
  final bool noPlan;
  final int limit;
  final String? planName;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Post an Item'),
      body: Padding(
        padding: const EdgeInsets.all(Sp.page),
        child: Column(children: [
          const Spacer(),
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(color: C.tint, shape: BoxShape.circle),
            child: const Center(child: PhosphorIcon(PhosphorIconsDuotone.storefront, size: 44, color: C.primary)),
          ),
          const Gap(22),
          Text(noPlan ? 'Choose a seller plan' : 'Listing limit reached', style: T.h1),
          const Gap(8),
          Text(
            noPlan ? 'Selling on Crystal Pay needs an active plan. Plans start at ${money(plans.first.price)} a month for up to ${plans.first.listingLimit} listings.' : 'Your $planName plan allows $limit live listings. Mark items as sold, remove one, or upgrade to post more.',
            style: T.small.copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AppButton(label: noPlan ? 'See plans' : 'Upgrade plan', onPressed: () => context.push('/plans')),
          if (!noPlan) ...[
            const Gap(10),
            AppButton(label: 'Manage my listings', kind: BtnKind.soft, onPressed: () => context.push('/my-listings')),
          ],
        ]),
      ),
    );
  }
}
