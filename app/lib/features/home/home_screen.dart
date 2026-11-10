import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/account.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../market/listing_card.dart';
import 'banners.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final popular = [...feed.where((l) => l.isRealEstate), ...feed.where((l) => !l.isRealEstate && l.isFeatured), ...feed.where((l) => !l.isRealEstate && !l.isFeatured)].take(8).toList();
    final fresh = feed.where((l) => !popular.take(8).contains(l)).take(4).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: C.bg,
        body: RefreshIndicator(
          color: C.primary,
          onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 700)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(Sp.page, 16, Sp.page, 0), child: _BalanceStrip())),
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 16), child: HeroCarousel())),
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(Sp.page, 18, Sp.page, 0), child: _QuickActions())),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: SectionHeader('Explore Categories', action: 'See All', onAction: () => context.go('/shop')),
                ),
              ),
              const SliverToBoxAdapter(child: _CategoryTiles()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.page, 24, Sp.page, 0),
                  child: PromoBanner(
                    eyebrow: 'Pay Bills Easily',
                    title: 'Never Stress About Bills Again',
                    subtitle: 'Electricity, data, TV and more.',
                    cta: 'Pay Now',
                    image: 'assets/illustrations/bills_phone.webp',
                    height: 176,
                    onTap: () => context.go('/bills'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: SectionHeader('Popular Listings', action: 'See All', onAction: () => context.go('/shop')),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 236,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.page),
                    itemCount: popular.length,
                    separatorBuilder: (_, _) => const HGap(12),
                    itemBuilder: (_, i) => SizedBox(width: 172, child: PopularCard(popular[i])),
                  ),
                ),
              ),
              if (fresh.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: SectionHeader('Just Listed', action: 'See All', onAction: () => context.go('/shop')),
                  ),
                ),
                SliverToBoxAdapter(child: ListingGrid(fresh)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acct = ref.watch(accountProvider);
    final unreadNotes = ref.watch(unreadNotesProvider);
    final cart = ref.watch(cartProvider).length;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page, 14, Sp.page - 4, 0),
        child: Row(children: [
          Pressable(
            onTap: () => context.go('/more'),
            child: Avatar(asset: acct.photo, name: acct.fullName, size: 44, verified: acct.idVerified),
          ),
          const HGap(12),
          Expanded(
            child: Text('Hi, ${acct.firstName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.h3.copyWith(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.3)),
          ),
          _PlainIcon(icon: PhosphorIconsRegular.headset, label: 'HELP', onTap: () => context.push('/help/chat'), semantics: 'Help'),
          _PlainIcon(icon: PhosphorIconsRegular.shoppingCart, count: cart, onTap: () => context.push('/cart'), semantics: 'Cart'),
          _PlainIcon(icon: PhosphorIconsRegular.bell, count: unreadNotes, onTap: () => context.push('/notifications'), semantics: 'Notifications'),
        ]),
      ),
    );
  }
}

/// Header icon without a background, with an optional count or text badge.
class _PlainIcon extends StatelessWidget {
  const _PlainIcon({required this.icon, required this.onTap, required this.semantics, this.count = 0, this.label});
  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String semantics;
  final int count;
  final String? label;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? '$semantics, $count new' : semantics,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            PhosphorIcon(icon, size: 27, color: C.ink),
            if (label != null)
              Positioned(
                top: 2,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(color: const Color(0xFFFBE4FF), borderRadius: BorderRadius.circular(6)),
                  child: Text(label!, style: const TextStyle(fontFamily: T.family, fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFB0189E), letterSpacing: .2, height: 1.2)),
                ),
              ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF25A6B), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bg, width: 1.5)),
                  alignment: Alignment.center,
                  child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(fontFamily: T.family, color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.1)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Wallet strip ─────────────────────────

class _BalanceStrip extends ConsumerWidget {
  const _BalanceStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    return Pressable(
      onTap: () => context.push('/wallet'),
      scale: .985,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border), boxShadow: softShadow(.05)),
        child: Row(children: [
          const IconTile('wallet', size: 46, bg: C.tint),
          const HGap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Wallet Balance', style: T.small.copyWith(fontSize: 12)),
              const Gap(2),
              Row(children: [
                Flexible(child: Text(hidden ? '₦ ••••••' : money2(w.balance), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.moneyOf(19))),
                const HGap(8),
                Pressable(
                  onTap: () => ref.read(balanceHiddenProvider.notifier).toggle(),
                  child: Padding(padding: const EdgeInsets.all(2), child: PhosphorIcon(hidden ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 17, color: C.muted)),
                ),
              ]),
            ]),
          ),
          Pressable(
            onTap: () => context.push('/wallet/add'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const PhosphorIcon(PhosphorIconsBold.plus, size: 13, color: Colors.white),
                const HGap(5),
                Text('Add Money', style: T.label.copyWith(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Quick actions ─────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final items = <(String, String, VoidCallback)>[
      ('Shop\nMarketplace', 'shop', () => context.go('/shop')),
      ('Buy Land\n& Property', 'houses', () => context.go('/shop?cat=houses')),
      ('Pay\nBills', 'bills', () => context.go('/bills')),
      ('More\nServices', 'more', () => showServicesSheet(context)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.border), boxShadow: softShadow(.05)),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 10), color: C.border),
            Expanded(
              child: Pressable(
                onTap: items[i].$3,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon3D(items[i].$2, size: 42),
                  const Gap(8),
                  Text(items[i].$1, textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// "More Services": every shortcut in one sheet.
Future<void> showServicesSheet(BuildContext context) {
  final items = <(String, String, String, bool)>[
    ('Send Money', 'send', '/send', false),
    ('Add Money', 'wallet', '/wallet/add', false),
    ('Sell an Item', 'store', '/sell', false),
    ('Cart', 'cart', '/cart', false),
    ('Seller Plans', 'crown', '/plans', false),
    ('Intl Airtime', 'intl', '/bills/international', false),
    ('My Orders', 'orders', '/orders', false),
    ('Favorites', 'favorites', '/saved', false),
    ('Messages', 'messages', '/chats', false),
    ('Refer & Earn', 'gift', '/refer', false),
    ('Insights', 'chart', '/insights', false),
    ('Support', 'help', '/help', false),
  ];
  return showAppSheet<void>(
    context,
    builder: (ctx) => SheetFrame(
      title: 'More Services',
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 8,
        childAspectRatio: .82,
        children: [
          for (final it in items)
            Pressable(
              onTap: () {
                Navigator.pop(ctx);
                context.push(it.$3);
              },
              child: Column(children: [
                IconTile(it.$2, size: 58, bg: C.tint),
                const Gap(7),
                Text(it.$1, textAlign: TextAlign.center, maxLines: 2, style: T.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2)),
              ]),
            ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Categories ─────────────────────────

class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sp.page),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const HGap(10),
        itemBuilder: (_, i) {
          final c = categories[i];
          final bg = c.id == 'lands' ? C.greenTint : C.tint;
          return Pressable(
            onTap: () => context.go('/shop?cat=${c.id}'),
            child: Container(
              width: 92,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(R.tile), border: Border.all(color: Colors.white, width: 1.5)),
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
              child: Column(children: [
                Expanded(child: Icon3D(c.id, size: 50)),
                const Gap(6),
                Text(categoryShort(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Popular listing card ─────────────────────────

/// Compact horizontal card from the home design: image + badge + price + title.
class PopularCard extends StatelessWidget {
  const PopularCard(this.l, {super.key});
  final Listing l;
  @override
  Widget build(BuildContext context) {
    final rent = l.isRental;
    final period = l.pricePeriod;
    return Pressable(
      onTap: () => context.push('/item/${l.id}'),
      scale: .98,
      child: Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.border), boxShadow: softShadow(.04)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 132,
            child: Stack(fit: StackFit.expand, children: [
              ProductImage(l.images.first),
              Positioned(left: 8, top: 8, child: listingBadge(l)),
              Positioned(right: 8, top: 8, child: SaveButton(l.id, size: 30)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: money(l.price)),
                  if (rent && period != null) TextSpan(text: ' ${period.replaceFirst('Per ', '/').replaceFirst('year', 'yr').replaceFirst('month', 'mo')}', style: T.small.copyWith(fontWeight: FontWeight.w700, color: C.ink)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.moneyOf(15.5, w: FontWeight.w800),
              ),
              const Gap(3),
              Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.small.copyWith(color: C.muted, fontSize: 12.5, height: 1.3)),
            ]),
          ),
        ]),
      ),
    );
  }
}
