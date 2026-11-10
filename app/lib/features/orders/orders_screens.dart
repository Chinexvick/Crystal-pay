import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../market/listing_card.dart';

String stageLabel(OrderStage s, OrderRole r, String method) => switch (s) {
      OrderStage.paid => r == OrderRole.selling ? 'Awaiting you' : 'Paid · held safely',
      OrderStage.shipped => method == 'Pickup' ? 'Ready for pickup' : 'On the way',
      OrderStage.delivered => 'Delivered',
      OrderStage.completed => 'Completed',
      OrderStage.cancelled => 'Cancelled',
    };

(Color, Color) stageColors(OrderStage s) => switch (s) {
      OrderStage.completed => (C.tint, C.primary),
      OrderStage.cancelled => (C.errorTint, C.error),
      OrderStage.paid => (C.goldTint, C.pending),
      _ => (C.violetTint, C.violet),
    };

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final role = _tab == 0 ? OrderRole.buying : OrderRole.selling;
    final list = ref.watch(ordersProvider).where((o) => o.role == role).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'My Orders'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 14),
          child: SegmentedToggle2(options: const ['Buying', 'Selling'], index: _tab, onChanged: (v) => setState(() => _tab = v)),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(
                  icon: PhosphorIconsDuotone.package,
                  title: role == OrderRole.buying ? 'No purchases yet' : 'No sales yet',
                  message: role == OrderRole.buying ? 'Items you buy will show up here.' : 'When someone buys your item, the order appears here.',
                  actionLabel: role == OrderRole.buying ? 'Browse market' : 'Sell an item',
                  onAction: () => role == OrderRole.buying ? context.go('/shop') : context.push('/sell'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Gap(12),
                  itemBuilder: (_, i) => _OrderCard(list[i]),
                ),
        ),
      ]),
    );
  }
}

/// Pill-style two option switch used across tabs.
class SegmentedToggle2 extends StatelessWidget {
  const SegmentedToggle2({super.key, required this.options, required this.index, required this.onChanged});
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Row(children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(i),
              scale: .98,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                decoration: BoxDecoration(color: i == index ? C.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(options[i], style: T.label.copyWith(color: i == index ? Colors.white : C.muted, fontSize: 13.5)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = stageColors(o.stage);
    return AppCard(
      onTap: () => context.push('/order/${o.id}'),
      child: Column(children: [
        Row(children: [
          Text(o.id, style: T.small.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Tag(stageLabel(o.stage, o.role, o.method), bg: bg, fg: fg),
        ]),
        const Gap(12),
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 64, child: ProductImage(o.listing.images.first))),
          const HGap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.listing.title, style: T.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const Gap(4),
              Text('${o.role == OrderRole.buying ? 'From' : 'To'} ${o.counterparty} · ${o.method}', style: T.small),
              const Gap(4),
              Text(money(o.total), style: T.moneyOf(15, color: C.primary)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(ordersProvider).where((x) => x.id == id).firstOrNull;
    if (o == null) {
      return Scaffold(backgroundColor: C.bg, appBar: const AppTopBar(title: 'Order Details'), body: const EmptyState(icon: PhosphorIconsDuotone.package, title: 'Order not found', message: 'It may have been removed.'));
    }
    final buying = o.role == OrderRole.buying;
    final cancelled = o.stage == OrderStage.cancelled;
    final idx = switch (o.stage) { OrderStage.paid => 0, OrderStage.shipped => 1, OrderStage.delivered => 2, OrderStage.completed => 3, OrderStage.cancelled => -1 };
    final steps = <(String, String)>[
      ('Order placed', buying ? 'Payment held by Crystal Protect' : 'Buyer has paid. Get the item ready'),
      (o.method == 'Pickup' ? 'Ready for pickup' : 'Shipped', o.method == 'Pickup' ? 'Meet at ${o.address}' : 'On its way to the buyer'),
      ('Delivered', 'Item has reached the buyer'),
      ('Completed', buying ? 'Seller has been paid' : 'Funds released to your wallet'),
    ];
    final notifier = ref.read(ordersProvider.notifier);
    final (bg, fg) = stageColors(o.stage);

    Widget? action;
    if (buying && o.stage == OrderStage.shipped) {
      action = AppButton(label: 'Confirm item received', icon: PhosphorIconsBold.check, onPressed: () {
        notifier.setStage(o.id, OrderStage.completed);
        showToast(context, 'Thanks! The seller has been paid.');
      });
    } else if (buying && o.stage == OrderStage.completed && !o.reviewed) {
      action = AppButton(label: 'Rate this seller', icon: PhosphorIconsBold.star, onPressed: () => _review(context, ref, o));
    } else if (!buying && o.stage == OrderStage.paid) {
      action = AppButton(label: o.method == 'Pickup' ? 'Mark ready for pickup' : 'Mark as shipped', icon: PhosphorIconsBold.truck, onPressed: () {
        notifier.setStage(o.id, OrderStage.shipped);
        showToast(context, 'Buyer has been notified');
      });
    } else if (!buying && o.stage == OrderStage.shipped) {
      action = AppButton(label: 'Buyer confirmed? Mark delivered', kind: BtnKind.soft, onPressed: () {
        notifier.setStage(o.id, OrderStage.completed);
        showToast(context, 'Funds released to your wallet');
      });
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Order ${o.id}'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 40), children: [
        AppCard(
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 72, height: 72, child: ProductImage(o.listing.images.first))),
            const HGap(14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.listing.title, style: T.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const Gap(6),
                Tag(stageLabel(o.stage, o.role, o.method), bg: bg, fg: fg),
              ]),
            ),
          ]),
        ),
        const Gap(18),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(children: [
            if (cancelled) const InfoBanner('This order was cancelled and refunded to the buyer.', kind: BannerKind.error),
            if (!cancelled)
              for (var i = 0; i < steps.length; i++) _Step(title: steps[i].$1, sub: steps[i].$2, done: i <= idx, current: i == idx, last: i == steps.length - 1),
          ]),
        ),
        const Gap(18),
        AppCard(
          child: Column(children: [
            KvRow(buying ? 'Seller' : 'Buyer', o.counterparty),
            KvRow('Handover', o.method),
            KvRow(o.method == 'Pickup' ? 'Pickup point' : 'Address', o.address),
            KvRow('Ordered', longDate(o.date)),
            const HairDivider(),
            KvRow('Item price', money(o.total - o.deliveryFee)),
            KvRow('Delivery', o.deliveryFee == 0 ? 'Free' : money(o.deliveryFee)),
            KvRow('Total', money(o.total), bold: true),
          ]),
        ),
        if (action != null) ...[const Gap(22), action],
        const Gap(10),
        AppButton(
          label: buying ? 'Chat with seller' : 'Chat with buyer',
          kind: BtnKind.secondary,
          icon: PhosphorIconsRegular.chatCircleDots,
          onPressed: () => context.push('/chat/${ref.read(chatsProvider.notifier).open(o.listing)}'),
        ),
        if (buying && o.stage != OrderStage.completed && !cancelled) ...[
          const Gap(10),
          Center(child: TextLink('Report a problem', trailing: false, color: C.error, onTap: () => showToast(context, 'Support will contact you shortly'))),
        ],
      ]),
    );
  }

  void _review(BuildContext context, WidgetRef ref, Order o) {
    showAppSheet<void>(context, builder: (_) => _ReviewSheet(onSubmit: () {
      ref.read(ordersProvider.notifier).markReviewed(o.id);
      showToast(context, 'Thanks for your review');
    }));
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.sub, required this.done, required this.current, required this.last});
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
              decoration: BoxDecoration(color: done ? C.primary : C.surface, shape: BoxShape.circle, border: Border.all(color: done ? C.primary : C.border, width: 2)),
              child: done ? const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 13, color: Colors.white)) : null,
            ),
            if (!last) Expanded(child: Container(width: 2, color: done && !current ? C.primary : C.border)),
          ]),
        ),
        const HGap(14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.title.copyWith(color: done ? C.ink : C.faint)),
              const Gap(2),
              Text(sub, style: T.small.copyWith(color: done ? C.muted : C.faint)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.onSubmit});
  final VoidCallback onSubmit;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _stars = 5;
  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Rate your experience',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            Pressable(
              onTap: () => setState(() => _stars = i),
              child: Padding(padding: const EdgeInsets.all(5), child: PhosphorIcon(i <= _stars ? PhosphorIconsFill.star : PhosphorIconsRegular.star, size: 38, color: C.gold)),
            ),
        ]),
        const Gap(14),
        const TextField(maxLines: 3, decoration: InputDecoration(hintText: 'Tell others about the item and seller (optional)')),
        const Gap(20),
        AppButton(label: 'Submit review', onPressed: () {
          Navigator.pop(context);
          widget.onSubmit();
        }),
      ]),
    );
  }
}
