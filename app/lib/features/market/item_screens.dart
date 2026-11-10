import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/catalog.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../bills/bill_common.dart';
import 'listing_card.dart';

const int kDeliveryFee = 2500;

// ───────────────────────── Item detail ─────────────────────────

class ItemScreen extends ConsumerStatefulWidget {
  const ItemScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends ConsumerState<ItemScreen> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(listingByIdProvider(widget.id));
    if (l == null) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: const AppTopBar(title: 'Item Details'),
        body: const EmptyState(icon: PhosphorIconsDuotone.package, title: 'Item not found', message: 'This listing may have been removed.'),
      );
    }
    final mine = l.seller.id == 'me';
    final similar = ref.watch(feedProvider).where((x) => x.id != l.id && x.categoryId == l.categoryId).take(6).toList();
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        ListView(padding: const EdgeInsets.only(bottom: 120), children: [
          // gallery
          SizedBox(
            height: 340 + top * 0,
            child: Stack(fit: StackFit.expand, children: [
              PageView.builder(
                controller: _page,
                itemCount: l.images.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PhotoViewer(images: l.images, index: i))),
                  child: i == 0 ? Hero(tag: 'img-${l.id}', child: ProductImage(l.images[i])) : ProductImage(l.images[i]),
                ),
              ),
              if (l.images.length > 1) ...[
                Positioned(
                  right: 14,
                  bottom: 34,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xB30B1F5C), borderRadius: BorderRadius.circular(999)),
                    child: Text('${_i + 1}/${l.images.length}', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 34,
                  child: Row(children: [
                    for (var k = 0; k < l.images.length; k++)
                      Pressable(
                        onTap: () => _page.animateToPage(k, duration: const Duration(milliseconds: 240), curve: Curves.easeOut),
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: k == _i ? C.primary : Colors.white, width: k == _i ? 2.2 : 1.5)),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ProductImage(l.images[k], forceCover: true)),
                        ),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
          Container(
            decoration: const BoxDecoration(color: C.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            transform: Matrix4.translationValues(0, -20, 0),
            padding: const EdgeInsets.fromLTRB(Sp.page, 22, Sp.page, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(money(l.price), style: T.moneyOf(28, color: C.primary)),
                if (l.isRealEstate && l.pricePeriod != null) Padding(padding: const EdgeInsets.only(left: 4, top: 8), child: Text(l.pricePeriod!.replaceFirst('Per ', '/ '), style: T.small)),
                const HGap(10),
                if (l.negotiable) const Tag('Negotiable', icon: PhosphorIconsBold.handshake),
                if (l.status == ListingStatus.sold) ...[const HGap(6), const Tag('Sold', bg: C.errorTint, fg: C.error)],
                const Spacer(),
                if (!mine && l.negotiable && !l.isRealEstate && l.status != ListingStatus.sold)
                  TextLink('Make an Offer', trailing: false, onTap: () => showOfferSheet(context, ref, l)),
              ]),
              const Gap(8),
              Text(l.title, style: T.h2.copyWith(fontSize: 19)),
              const Gap(10),
              Wrap(spacing: 14, runSpacing: 6, children: [
                _Meta(PhosphorIconsRegular.mapPin, l.location),
                _Meta(PhosphorIconsRegular.clock, timeAgo(l.postedAt)),
                _Meta(PhosphorIconsRegular.eye, '${l.views} views'),
              ]),
              const Gap(16),
              Row(children: [
                if (!l.isRealEstate) ...[Tag(l.condition.label, bg: C.tint, fg: C.primary), const HGap(8)],
                Tag(categoryById(l.categoryId).name, bg: C.bg, fg: C.muted),
              ]),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              color: C.surface,
              padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const HairDivider(),
                const Gap(16),
                if (!mine) _SellerCard(l.seller),
                if (!mine) const Gap(22),
                Text('Description', style: T.h3),
                const Gap(8),
                Text(l.description, style: T.body.copyWith(color: C.muted, height: 1.55)),
                if (l.specs.isNotEmpty) ...[
                  const Gap(22),
                  Text('Details', style: T.h3),
                  const Gap(6),
                  for (final e in l.specs.entries) KvRow(e.key, e.value),
                ],
                if (!l.isRealEstate) ...[
                  const Gap(18),
                  Text('Handover', style: T.h3),
                  const Gap(10),
                  Row(children: [
                    if (l.delivery) Expanded(child: _Option(PhosphorIconsDuotone.truck, 'Delivery', 'Available · ${money(kDeliveryFee)}')),
                    if (l.delivery && l.pickup) const HGap(10),
                    if (l.pickup) Expanded(child: _Option(PhosphorIconsDuotone.storefront, 'Pickup', 'Free · ${l.area}')),
                  ]),
                ],
                const Gap(20),
                if (l.isRealEstate) const _PropertyNotice() else const _ProtectBanner(),
                const Gap(14),
                Pressable(
                  onTap: () => _report(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const PhosphorIcon(PhosphorIconsRegular.flag, size: 16, color: C.faint),
                      const HGap(6),
                      Text('Report this listing', style: T.small.copyWith(color: C.faint, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          if (similar.isNotEmpty) ...[
            const Gap(6),
            SectionHeader('Similar items', action: 'See all', onAction: () => context.go('/shop?cat=${l.categoryId}')),
            ListingGrid(similar),
          ],
        ]),
        // floating header buttons
        Positioned(
          top: top + 8,
          left: 14,
          right: 14,
          child: Row(children: [
            RoundIconButton(icon: PhosphorIconsBold.caretLeft, onTap: () => context.pop(), bg: Colors.white.withValues(alpha: .94), size: 42),
            const Spacer(),
            RoundIconButton(icon: PhosphorIconsRegular.shareNetwork, onTap: () => showToast(context, 'Link copied', icon: PhosphorIconsFill.link), bg: Colors.white.withValues(alpha: .94), size: 42),
            const HGap(10),
            if (!mine) SaveButton(l.id, size: 42),
          ]),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _BottomBar(l: l, mine: mine)),
      ]),
    );
  }

  void _report(BuildContext context) {
    showAppSheet<void>(context, builder: (_) => const _ReportSheet());
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final PhosphorIconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        PhosphorIcon(icon, size: 14, color: C.faint),
        const HGap(4),
        Text(text, style: T.small.copyWith(fontSize: 12.5)),
      ]);
}

class _Option extends StatelessWidget {
  const _Option(this.icon, this.title, this.sub);
  final PhosphorIconData icon;
  final String title, sub;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          IconChip(icon, size: 38, bg: C.surface),
          const HGap(10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.title.copyWith(fontSize: 14)),
              Text(sub, style: T.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

class _SellerCard extends StatelessWidget {
  const _SellerCard(this.s);
  final Seller s;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/seller/${s.id}'),
      padding: const EdgeInsets.all(14),
      color: C.bg,
      borderColor: null,
      child: Row(children: [
        Avatar(asset: s.avatar, name: s.name, size: 50, verified: s.verified),
        const HGap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: T.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Gap(3),
            Row(children: [
              const PhosphorIcon(PhosphorIconsFill.star, size: 13, color: C.gold),
              const HGap(3),
              Text('${s.rating} · ${s.reviews} reviews · ${s.sold} sold', style: T.small.copyWith(fontSize: 12)),
            ]),
            const Gap(2),
            Text(s.response, style: T.caption),
          ]),
        ),
        const PhosphorIcon(PhosphorIconsBold.caretRight, size: 15, color: C.faint),
      ]),
    );
  }
}

/// Real estate is never paid for on the platform (see Terms, section 6).
class _PropertyNotice extends StatelessWidget {
  const _PropertyNotice();
  @override
  Widget build(BuildContext context) => const InfoBanner(
        'Property deals happen directly between you and the seller, outside Crystal Pay. Inspect the property and check its documents before you pay anyone, and never pay through the app or to someone you have not met. Crystal Pay does not hold or protect property payments.',
        kind: BannerKind.warning,
        icon: PhosphorIconsFill.warning,
      );
}

class _ProtectBanner extends StatelessWidget {
  const _ProtectBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: C.deepGradient, borderRadius: BorderRadius.circular(18)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: PhosphorIcon(PhosphorIconsFill.shieldCheck, size: 22, color: Colors.white)),
        ),
        const HGap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Crystal Protect', style: T.title.copyWith(color: Colors.white)),
            const Gap(3),
            Text('Pay from your wallet. The seller is only paid after you confirm you received the item.',
                style: T.small.copyWith(color: Colors.white.withValues(alpha: .8), fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.l, required this.mine});
  final Listing l;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sold = l.status == ListingStatus.sold;
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: C.surface, border: const Border(top: BorderSide(color: C.border)), boxShadow: softShadow(.06)),
      child: mine
          ? Row(children: [
              Expanded(child: AppButton(label: 'Edit Price', kind: BtnKind.secondary, icon: PhosphorIconsRegular.pencilSimple, onPressed: () => showEditPriceSheet(context, ref, l))),
              const HGap(10),
              Expanded(
                child: AppButton(
                  label: sold ? 'Relist' : 'Mark as Sold',
                  icon: sold ? PhosphorIconsBold.arrowsClockwise : PhosphorIconsBold.check,
                  onPressed: () {
                    ref.read(listingsProvider.notifier).setStatus(l.id, sold ? ListingStatus.active : ListingStatus.sold);
                    showToast(context, sold ? 'Listing is live again' : 'Marked as sold');
                  },
                ),
              ),
            ])
          : l.isRealEstate
              ? Row(children: [
                  _ChatButton(l),
                  const HGap(10),
                  Expanded(child: AppButton(label: 'Contact Seller', icon: PhosphorIconsBold.phone, onPressed: () => showAppSheet<void>(context, builder: (_) => ContactSellerSheet(l)))),
                ])
              : Row(children: [
              Pressable(
                onTap: () {
                  final id = ref.read(chatsProvider.notifier).open(l);
                  context.push('/chat/$id');
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: PhosphorIcon(PhosphorIconsDuotone.chatCircleDots, size: 26, color: C.primary)),
                ),
              ),
              const HGap(10),
              if (!sold) ...[
                Expanded(
                  child: AppButton(
                    label: ref.watch(cartProvider).contains(l.id) ? 'In Cart' : 'Add to Cart',
                    kind: BtnKind.secondary,
                    icon: ref.watch(cartProvider).contains(l.id) ? PhosphorIconsBold.check : null,
                    onPressed: () {
                      if (ref.read(cartProvider).contains(l.id)) {
                        context.push('/cart');
                      } else {
                        ref.read(cartProvider.notifier).add(l.id);
                        showToast(context, 'Added to cart', icon: PhosphorIconsFill.shoppingCart);
                      }
                    },
                  ),
                ),
                const HGap(10),
              ],
              Expanded(child: AppButton(label: sold ? 'Sold Out' : 'Buy Now', onPressed: sold ? null : () => context.push('/checkout/${l.id}'))),
            ]),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int _sel = -1;
  static const _reasons = ['Scam or fraud', 'Prohibited item', 'Wrong category', 'Misleading price or photos', 'Something else'];
  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Report listing',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < _reasons.length; i++)
          Pressable(
            onTap: () => setState(() => _sel = i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(children: [
                Expanded(child: Text(_reasons[i], style: T.bodyM)),
                RadioDot(selected: _sel == i),
              ]),
            ),
          ),
        const Gap(14),
        AppButton(
          label: 'Submit report',
          onPressed: _sel < 0
              ? null
              : () {
                  Navigator.pop(context);
                  showToast(context, 'Thanks. Our team will review this listing.');
                },
        ),
      ]),
    );
  }
}

// ───────────────────────── Offer & edit price sheets ─────────────────────────

Future<void> showOfferSheet(BuildContext context, WidgetRef ref, Listing l) {
  return showAppSheet<void>(context, builder: (_) => _OfferSheet(l: l, ref: ref, parent: context));
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.l, required this.ref, required this.parent});
  final Listing l;
  final WidgetRef ref;
  final BuildContext parent;
  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _c = TextEditingController();
  int get _v => int.tryParse(_c.text.replaceAll(',', '')) ?? 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.l.price;
    final ok = _v > 0 && _v <= p;
    return SheetFrame(
      title: 'Make an offer',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Asking price ${money(p)}. A fair offer gets a faster reply.', style: T.small.copyWith(fontSize: 13)),
        const Gap(16),
        AmountField(controller: _c, hint: 'Your offer', onChanged: (_) => setState(() {}), error: _v > p ? 'Offer cannot exceed the asking price' : null),
        const Gap(14),
        Row(children: [
          for (final pct in [5, 10, 15]) ...[
            Expanded(
              child: Pressable(
                onTap: () => setState(() => _c.text = ((p * (100 - pct) / 100) ~/ 100 * 100).toString()),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text('-$pct%', style: T.label.copyWith(color: C.primary)),
                ),
              ),
            ),
            if (pct != 15) const HGap(8),
          ],
        ]),
        const Gap(22),
        AppButton(
          label: 'Send offer',
          onPressed: ok
              ? () {
                  final chats = widget.ref.read(chatsProvider.notifier);
                  final id = chats.open(widget.l);
                  chats.send(id, 'Hi, would you accept ${money(_v)} for this?', offer: _v);
                  Navigator.pop(context);
                  widget.parent.push('/chat/$id');
                  simulateReply(widget.ref, id, offer: _v, asking: p);
                }
              : null,
        ),
      ]),
    );
  }
}

/// Fake seller response so the chat feels alive.
void simulateReply(WidgetRef ref, String id, {int? offer, int? asking}) {
  Future<void>.delayed(const Duration(milliseconds: 1800), () {
    String text;
    if (offer != null && asking != null) {
      text = offer >= asking * .9 ? 'Deal. You can go ahead and pay with Crystal Pay.' : 'Thanks for the offer. Could you do ${money((asking * .92).round() ~/ 100 * 100)}?';
    } else {
      text = 'Hello! Yes, it is still available.';
    }
    try {
      ref.read(chatsProvider.notifier).reply(id, text);
    } catch (_) {}
  });
}

Future<void> showEditPriceSheet(BuildContext context, WidgetRef ref, Listing l) {
  final c = TextEditingController(text: l.price.toString());
  return showAppSheet<void>(
    context,
    builder: (ctx) => SheetFrame(
      title: 'Edit price',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AmountField(controller: c, hint: 'New price'),
        const Gap(20),
        AppButton(
          label: 'Save price',
          onPressed: () {
            final v = int.tryParse(c.text.replaceAll(',', '')) ?? 0;
            if (v <= 0) return;
            ref.read(listingsProvider.notifier).update(l.copyWith(price: v));
            Navigator.pop(ctx);
            showToast(context, 'Price updated to ${money(v)}');
          },
        ),
      ]),
    ),
  );
}

// ───────────────────────── Checkout ─────────────────────────

class _ChatButton extends ConsumerWidget {
  const _ChatButton(this.l);
  final Listing l;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Pressable(
        onTap: () {
          final id = ref.read(chatsProvider.notifier).open(l);
          context.push('/chat/$id');
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(16)),
          child: const Center(child: PhosphorIcon(PhosphorIconsDuotone.chatCircleDots, size: 26, color: C.primary)),
        ),
      );
}

class ContactSellerSheet extends ConsumerWidget {
  const ContactSellerSheet(this.l, {super.key});
  final Listing l;

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showToast(context, 'Could not open that app', error: true);
    } catch (_) {
      if (context.mounted) showToast(context, 'Could not open that app', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = l.contactPhone;
    final intl = phone == null ? null : '234${phone.replaceFirst(RegExp(r'^0'), '')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Contact ${l.seller.name.split(' ').first}', style: T.h2),
        const Gap(4),
        Text('Talk to the seller to view the property and agree terms. Payment is arranged between you, not on Crystal Pay.', style: T.small),
        const Gap(16),
        if (phone == null)
          AppButton(label: 'Chat with seller', onPressed: () {
            Navigator.of(context).pop();
            final id = ref.read(chatsProvider.notifier).open(l);
            context.push('/chat/$id');
          })
        else ...[
          KvRow('Phone', phone, copyable: true),
          const Gap(12),
          Row(children: [
            Expanded(child: AppButton(label: 'Call', icon: PhosphorIconsBold.phone, onPressed: () => _open(context, Uri.parse('tel:+$intl')))),
            const HGap(10),
            Expanded(child: AppButton(label: 'WhatsApp', kind: BtnKind.secondary, icon: PhosphorIconsBold.chatCircleDots, onPressed: () => _open(context, Uri.parse('https://wa.me/$intl?text=${Uri.encodeComponent('Hello, I saw your listing "${l.title}" on Crystal Pay.')}')))),
          ]),
          const Gap(10),
          AppButton(label: 'Chat in the app', kind: BtnKind.soft, onPressed: () {
            Navigator.of(context).pop();
            final id = ref.read(chatsProvider.notifier).open(l);
            context.push('/chat/$id');
          }),
        ],
        const Gap(14),
        const InfoBanner('Meet in a public place or at the property. Do not send money before you have inspected it and checked the documents.', kind: BannerKind.warning),
      ]),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.id, this.price});
  final String id;
  final int? price;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _method = 0; // 0 delivery, 1 pickup
  final _addr = TextEditingController(text: '12 Admiralty Way, Lekki Phase 1, Lagos');

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(listingByIdProvider(widget.id));
    if (l == null) return const Scaffold(body: SizedBox());
    if (l.isRealEstate) {
      // Property cannot be paid for on the platform; never reach checkout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/item/${l.id}');
      });
      return const Scaffold(body: SizedBox());
    }
    final price = widget.price ?? l.price;
    final methods = <String>[if (l.delivery) 'Delivery', if (l.pickup) 'Pickup'];
    final delivery = methods[_method.clamp(0, methods.length - 1)] == 'Delivery';
    final fee = delivery ? kDeliveryFee : 0;
    final total = price + fee;
    final bal = ref.watch(walletProvider).balance;
    final short = total > bal;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Checkout'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        AppCard(
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 72, height: 72, child: ProductImage(l.images.first))),
            const HGap(14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title, style: T.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const Gap(4),
                Text('Sold by ${l.seller.name}', style: T.small),
                const Gap(4),
                Text(money(price), style: T.moneyOf(16, color: C.primary)),
              ]),
            ),
          ]),
        ),
        const Gap(22),
        Text('How do you want it?', style: T.h3),
        const Gap(12),
        SegmentedToggle(options: methods, index: _method.clamp(0, methods.length - 1), onChanged: (v) => setState(() => _method = v)),
        const Gap(16),
        if (delivery)
          AppTextField(controller: _addr, label: 'Delivery address', maxLines: 2, prefix: const Padding(padding: EdgeInsets.only(left: 14, right: 4), child: PhosphorIcon(PhosphorIconsRegular.mapPin, size: 20, color: C.muted)), onChanged: (_) => setState(() {}))
        else
          InfoBanner('Pick up from ${l.area}, ${l.city}. The seller will share the exact meeting point in chat.'),
        const Gap(22),
        Text('Payment', style: T.h3),
        const Gap(12),
        AppCard(
          child: Row(children: [
            const IconChip(PhosphorIconsDuotone.wallet, size: 44),
            const HGap(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Crystal wallet', style: T.title),
                Text('Balance ${money2(bal)}', style: T.small.copyWith(color: short ? C.error : C.muted)),
              ]),
            ),
            if (short) TextLink('Add money', onTap: () => context.push('/wallet/add'), trailing: false),
          ]),
        ),
        const Gap(22),
        AppCard(
          child: Column(children: [
            KvRow('Item price', money(price)),
            KvRow(delivery ? 'Delivery fee' : 'Pickup', delivery ? money(fee) : 'Free'),
            const HairDivider(),
            KvRow('Total', money(total), bold: true),
          ]),
        ),
        const Gap(16),
        const InfoBanner('Your money is held by Crystal Protect and released to the seller once you confirm delivery.'),
        const Gap(24),
        AppButton(
          label: 'Pay ${money(total)}',
          onPressed: (delivery && _addr.text.trim().length < 6) ? null : () => _pay(l, price, fee, total, delivery),
        ),
      ]),
    );
  }

  Future<void> _pay(Listing l, int price, int fee, int total, bool delivery) async {
    if (total > ref.read(walletProvider).balance) {
      showToast(context, 'Insufficient wallet balance', error: true);
      return;
    }
    final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: total));
    if (pin != true || !mounted) return;
    showDialog<void>(context: context, barrierDismissible: false, barrierColor: C.scrim, builder: (_) => const ProcessingDialog());
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    try {
      final order = ref.read(ordersProvider.notifier).place(l, method: delivery ? 'Delivery' : 'Pickup', address: delivery ? _addr.text.trim() : '${l.area}, ${l.city}', deliveryFee: fee, total: total);
      ref.read(walletProvider.notifier).pay(
        kind: TxKind.purchase,
        title: l.title,
        subtitle: 'Order ${order.id}',
        amount: total,
        details: {'Order': order.id, 'Seller': l.seller.name, 'Method': order.method},
      );
      ref.read(listingsProvider.notifier).setStatus(l.id, ListingStatus.sold);
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/order-placed/${order.id}');
    } on InsufficientFunds {
      if (mounted) showToast(context, 'Insufficient wallet balance', error: true);
    }
  }
}

class OrderPlacedScreen extends ConsumerWidget {
  const OrderPlacedScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(ordersProvider).where((x) => x.id == id).firstOrNull;
    return Scaffold(
      backgroundColor: C.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.page),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(gradient: C.brandGradient, shape: BoxShape.circle),
              child: const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 52, color: Colors.white)),
            ),
            const Gap(26),
            Text('Order placed', style: T.h1),
            const Gap(8),
            Text('Your payment is safe with Crystal Protect.\nWe have told ${o?.counterparty ?? 'the seller'} to get it ready.', style: T.small.copyWith(fontSize: 14), textAlign: TextAlign.center),
            const Gap(26),
            if (o != null)
              AppCard(
                color: C.bg,
                borderColor: null,
                child: Column(children: [
                  KvRow('Order ID', o.id),
                  KvRow('Item', o.listing.title),
                  KvRow('Handover', o.method),
                  KvRow('Total paid', money(o.total), bold: true),
                ]),
              ),
            const Spacer(),
            AppButton(label: 'Track order', onPressed: () => context.go('/order/$id')),
            const Gap(10),
            AppButton(label: 'Back to home', kind: BtnKind.soft, onPressed: () => context.go('/home')),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Seller profile ─────────────────────────

class SellerScreen extends ConsumerStatefulWidget {
  const SellerScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends ConsumerState<SellerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.id == 'me' ? meSeller : sellers.firstWhere((x) => x.id == widget.id, orElse: () => sellers.first);
    final items = ref.watch(feedProvider).where((l) => l.seller.id == s.id).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Seller Profile'),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Container(
          color: C.surface,
          padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 20),
          child: Column(children: [
            Avatar(asset: s.avatar, name: s.name, size: 84, verified: s.verified),
            const Gap(14),
            Text(s.name, style: T.h2),
            const Gap(4),
            Text('${s.city} · ${s.joined}', style: T.small.copyWith(fontSize: 13)),
            const Gap(18),
            Row(children: [
              _Stat('${s.rating}', 'Rating'),
              _Stat('${s.reviews}', 'Reviews'),
              _Stat('${s.sold}', 'Sold'),
            ]),
          ]),
        ),
        const Gap(14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.page), child: UnderlineTabs(items: const ['Listings', 'Reviews'], index: _tab, onChanged: (v) => setState(() => _tab = v))),
        const Gap(16),
        if (_tab == 0)
          items.isEmpty
              ? const Padding(padding: EdgeInsets.only(top: 30), child: EmptyState(icon: PhosphorIconsDuotone.package, title: 'No active listings', message: 'This seller has nothing for sale right now.'))
              : ListingGrid(items)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.page),
            child: Column(children: [for (final r in mockReviews) _ReviewTile(r)]),
          ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.v, this.k);
  final String v, k;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(v, style: T.moneyOf(20)),
          const Gap(2),
          Text(k, style: T.small),
        ]),
      );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.r);
  final Review r;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(asset: r.avatar, name: r.author, size: 36),
              const HGap(10),
              Expanded(child: Text(r.author, style: T.title)),
              Text(r.when, style: T.caption),
            ]),
            const Gap(8),
            Row(children: [
              for (var i = 0; i < 5; i++) PhosphorIcon(i < r.rating ? PhosphorIconsFill.star : PhosphorIconsRegular.star, size: 14, color: C.gold),
            ]),
            const Gap(8),
            Text(r.text, style: T.body.copyWith(color: C.muted)),
          ]),
        ),
      );
}


/// Full-screen swipeable, pinch-to-zoom photo viewer.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.images, this.index = 0});
  final List<String> images;
  final int index;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _c = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, title: Text('${_i + 1} of ${widget.images.length}', style: T.title.copyWith(color: Colors.white))),
      body: PageView.builder(
        controller: _c,
        itemCount: widget.images.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (_, i) => InteractiveViewer(minScale: 1, maxScale: 4, child: Center(child: Image(image: imageFor(widget.images[i]), fit: BoxFit.contain))),
      ),
    );
  }
}
