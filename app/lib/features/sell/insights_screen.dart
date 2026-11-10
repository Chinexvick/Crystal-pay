import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/account.dart';
import '../../data/models.dart';
import '../../data/plans.dart';
import '../../data/state.dart';
import '../market/listing_card.dart';

/// Seller insights. Included in Pro and Business.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acct = ref.watch(accountProvider);
    final allowed = acct.planActive && acct.plan != PlanId.basic;
    final mine = ref.watch(myListingsProvider).where((l) => l.status != ListingStatus.draft).toList()..sort((a, b) => b.views.compareTo(a.views));
    final views = mine.fold<int>(0, (a, l) => a + l.views);
    final saves = mine.fold<int>(0, (a, l) => a + l.saves);
    final top = mine.isEmpty ? 1 : mine.first.views.clamp(1, 1 << 30);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Seller Insights'),
      body: !allowed
          ? Padding(
              padding: const EdgeInsets.all(Sp.page),
              child: Column(children: [
                const Spacer(),
                const IconTile('chart', size: 96, bg: C.tint),
                const Gap(22),
                Text('See how your items perform', style: T.h2),
                const Gap(8),
                Text('Views, saves and your best listings, item by item. Included in the Pro and Business plans.', style: T.small.copyWith(fontSize: 14), textAlign: TextAlign.center),
                const Spacer(),
                AppButton(label: 'See Plans', onPressed: () => context.push('/plans')),
              ]),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 32), children: [
              Row(children: [
                Expanded(child: _Stat('Views', '$views', PhosphorIconsDuotone.eye)),
                const HGap(10),
                Expanded(child: _Stat('Saves', '$saves', PhosphorIconsDuotone.heart)),
                const HGap(10),
                Expanded(child: _Stat('Save rate', views == 0 ? '0%' : '${(saves * 100 / views).toStringAsFixed(1)}%', PhosphorIconsDuotone.chartBar)),
              ]),
              const Gap(22),
              Text('By listing', style: T.h3),
              const Gap(10),
              if (mine.isEmpty)
                const InfoBanner('Post an item and its numbers will show up here.')
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    for (var i = 0; i < mine.length; i++) ...[
                      if (i > 0) const HairDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 44, height: 44, child: ProductImage(mine[i].images.first))),
                          const HGap(12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(mine[i].title, style: T.bodyM, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const Gap(6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: mine[i].views / top, minHeight: 6, backgroundColor: C.tint, color: C.primary),
                              ),
                            ]),
                          ),
                          const HGap(12),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${mine[i].views} views', style: T.label),
                            Text('${mine[i].saves} saves', style: T.caption),
                          ]),
                        ]),
                      ),
                    ],
                  ]),
                ),
              const Gap(14),
              Text('Last 30 days. Figures update as buyers view and save your items.', style: T.small),
            ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label, value;
  final PhosphorIconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PhosphorIcon(icon, size: 22, color: C.primary),
          const Gap(10),
          Text(value, style: T.moneyOf(22)),
          Text(label, style: T.small),
        ]),
      );
}

/// Boost sheet shown from My listings.
Future<void> showBoostSheet(BuildContext context, WidgetRef ref, Listing l) {
  return showAppSheet<void>(context, builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final acct = ref.watch(accountProvider);
        final plan = acct.planActive ? planById(acct.plan!) : null;
        final total = plan?.boostsPerMonth ?? 0;
        final left = acct.boostsLeft;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Boost this listing', style: T.h2),
            const Gap(6),
            Text('A boosted item sits at the top of search and its category for 7 days, with a Featured tag.', style: T.small.copyWith(fontSize: 13.5)),
            const Gap(16),
            if (total == 0)
              InfoBanner('Boosts are part of the Pro and Business plans.', action: 'See plans', onAction: () {
                Navigator.of(ctx).pop();
                context.push('/plans');
              })
            else ...[
              KvRow('Boosts left this month', '$left of $total'),
              if (l.isBoosted) KvRow('Already boosted until', '${l.boostedUntil!.day}/${l.boostedUntil!.month}/${l.boostedUntil!.year}'),
              const Gap(14),
              AppButton(
                label: left == 0 ? 'No boosts left' : (l.isBoosted ? 'Extend by 7 days' : 'Boost for 7 days'),
                onPressed: left == 0
                    ? null
                    : () {
                        ref.read(accountProvider.notifier).useBoost();
                        ref.read(listingsProvider.notifier).boost(l.id);
                        Navigator.of(ctx).pop();
                        showToast(context, 'Listing boosted for 7 days');
                      },
              ),
            ],
          ]),
        );
      }));
}
