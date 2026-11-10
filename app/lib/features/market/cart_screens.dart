import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../bills/bill_common.dart' show PinSheet, ProcessingDialog;
import 'item_screens.dart' show kDeliveryFee;
import 'listing_card.dart';

/// Cart: buy several items in one payment. Each item becomes its own
/// Crystal Protect order, so every seller is paid only after you confirm.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _delivery = true;
  final _addr = TextEditingController(text: '12 Admiralty Way, Lekki Phase 1, Lagos');

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider);
    final bal = ref.watch(walletProvider).balance;
    final pickupOk = items.isNotEmpty && items.every((l) => l.pickup);
    final deliveryOk = items.isNotEmpty && items.every((l) => l.delivery);
    final delivery = deliveryOk ? (_delivery || !pickupOk) : false;
    final sellers = {for (final l in items) l.seller.id};
    final subtotal = items.fold<int>(0, (a, l) => a + l.price);
    final fees = delivery ? kDeliveryFee * sellers.length : 0;
    final total = subtotal + fees;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(
        title: 'My Cart',
        actionLabel: items.isEmpty ? null : 'Clear',
        onAction: () => ref.read(cartProvider.notifier).clear(),
      ),
      body: items.isEmpty
          ? EmptyState(icon: PhosphorIconsDuotone.shoppingCart, title: 'Your cart is empty', message: 'Add items from the Shop and pay for them together.', actionLabel: 'Browse Shop', onAction: () => context.go('/shop'))
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 6, Sp.page, 24), children: [
                  for (final l in items) ...[
                    _CartRow(l, onRemove: () => ref.read(cartProvider.notifier).remove(l.id)),
                    const Gap(10),
                  ],
                  const Gap(8),
                  Text('How do you want them?', style: T.h3),
                  const Gap(10),
                  Row(children: [
                    Expanded(child: _Choice('Delivery', '${money(kDeliveryFee)} per seller', delivery, deliveryOk ? () => setState(() => _delivery = true) : null)),
                    const HGap(10),
                    Expanded(child: _Choice('Pickup', 'Free, from each seller', !delivery, pickupOk ? () => setState(() => _delivery = false) : null)),
                  ]),
                  if (!deliveryOk || !pickupOk) ...[
                    const Gap(8),
                    Text(!deliveryOk ? 'Some sellers only offer pickup.' : 'Some sellers only offer delivery.', style: T.small),
                  ],
                  if (delivery) ...[
                    const Gap(14),
                    AppTextField(controller: _addr, label: 'Delivery address', prefix: const PhosphorIcon(PhosphorIconsRegular.mapPin, size: 18, color: C.muted), onChanged: (_) => setState(() {})),
                  ],
                  const Gap(18),
                  AppCard(
                    child: Column(children: [
                      KvRow('Items (${items.length})', money(subtotal)),
                      KvRow(delivery ? 'Delivery (${sellers.length} ${sellers.length == 1 ? 'seller' : 'sellers'})' : 'Pickup', delivery ? money(fees) : 'Free'),
                      const HairDivider(),
                      KvRow('Total', money(total), bold: true),
                      KvRow('Wallet balance', money2(bal), valueColor: bal < total ? C.error : C.muted),
                    ]),
                  ),
                  const Gap(12),
                  const InfoBanner('Crystal Protect holds your payment. Each seller is paid only after you confirm their item arrived.', icon: PhosphorIconsFill.shieldCheck),
                ]),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 12 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
                child: bal < total
                    ? AppButton(label: 'Add Money to Pay', icon: PhosphorIconsBold.plus, onPressed: () => context.push('/wallet/add'))
                    : AppButton(label: 'Pay ${money(total)}', onPressed: (delivery && _addr.text.trim().length < 6) ? null : () => _pay(items, delivery, total, sellers)),
              ),
            ]),
    );
  }

  Future<void> _pay(List<Listing> items, bool delivery, int total, Set<String> sellers) async {
    final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: total, subtitle: 'Pay for ${items.length} ${items.length == 1 ? 'item' : 'items'}'));
    if (pin != true || !mounted) return;
    showDialog<void>(context: context, barrierDismissible: false, barrierColor: C.scrim, builder: (_) => const ProcessingDialog());
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    try {
      final charged = <String>{};
      final ids = <String>[];
      for (final l in items) {
        final fee = delivery && charged.add(l.seller.id) ? kDeliveryFee : 0;
        final o = ref.read(ordersProvider.notifier).place(l, method: delivery ? 'Delivery' : 'Pickup', address: delivery ? _addr.text.trim() : '${l.area}, ${l.city}', deliveryFee: fee, total: l.price + fee);
        ids.add(o.id);
      }
      ref.read(walletProvider.notifier).pay(
            kind: TxKind.purchase,
            title: 'Cart checkout',
            subtitle: '${items.length} ${items.length == 1 ? 'item' : 'items'} · ${ids.join(', ')}',
            amount: total,
            details: {'Orders': ids.join(', '), 'Method': delivery ? 'Delivery' : 'Pickup'},
          );
      for (final l in items) {
        ref.read(listingsProvider.notifier).setStatus(l.id, ListingStatus.sold);
      }
      ref.read(cartProvider.notifier).clear();
      HapticFeedback.mediumImpact();
      if (mounted) context.pushReplacement('/cart/placed', extra: (items.length, total));
    } on InsufficientFunds {
      if (mounted) showToast(context, 'Insufficient wallet balance', error: true);
    }
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow(this.l, {required this.onRemove});
  final Listing l;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/item/${l.id}'),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 74, height: 74, child: ProductImage(l.images.first))),
        const HGap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14)),
            const Gap(2),
            Text('Sold by ${l.seller.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 12)),
            const Gap(4),
            Text(money(l.price), style: T.moneyOf(15, color: C.primary)),
          ]),
        ),
        Pressable(
          onTap: onRemove,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: C.errorTint, shape: BoxShape.circle),
            child: const Center(child: PhosphorIcon(PhosphorIconsRegular.trash, size: 17, color: C.error)),
          ),
        ),
      ]),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(this.title, this.sub, this.sel, this.onTap);
  final String title;
  final String sub;
  final bool sel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null && !sel ? .45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: sel ? C.tint : C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? C.primary : C.border, width: sel ? 1.5 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: T.title.copyWith(color: sel ? C.primary : C.ink))),
                if (sel) const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 18, color: C.primary),
              ]),
              const Gap(2),
              Text(sub, style: T.small.copyWith(fontSize: 12)),
            ]),
          ),
        ),
      );
}

class CartPlacedScreen extends StatelessWidget {
  const CartPlacedScreen({super.key, required this.count, required this.total});
  final int count;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.page),
          child: Column(children: [
            const Spacer(),
            Image.asset('assets/illustrations/shop_bags.webp', height: 170),
            const Gap(22),
            Text('Order placed', style: T.h1),
            const Gap(8),
            Text('You paid ${money(total)} for $count ${count == 1 ? 'item' : 'items'}. Sellers have been told to get them ready.', style: T.small.copyWith(fontSize: 14), textAlign: TextAlign.center),
            const Spacer(),
            AppButton(label: 'Track My Orders', onPressed: () => context.pushReplacement('/orders')),
            const Gap(10),
            AppButton(label: 'Continue Shopping', kind: BtnKind.soft, onPressed: () => context.go('/shop')),
          ]),
        ),
      ),
    );
  }
}
