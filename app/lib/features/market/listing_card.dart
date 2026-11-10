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
import 'item_screens.dart' show ContactSellerSheet;

/// Studio shots (white backdrop) are letter-boxed; lifestyle photos fill.
const _studio = {'phone', 'camera', 'speaker', 'chair', 'dress', 'tent', 'teddy', 'kettle_steel'};

bool _isStudio(String path) {
  final n = path.split('/').last.replaceAll('.jpg', '');
  return _studio.contains(n);
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.path, {super.key, this.aspect, this.radius = 0, this.forceCover = false});
  final String path;
  final double? aspect;
  final double radius;
  final bool forceCover;

  @override
  Widget build(BuildContext context) {
    final studio = path.startsWith('assets/') && _isStudio(path) && !forceCover;
    Widget img = Container(
      color: studio ? Colors.white : C.tint2,
      child: Image(
        image: imageFor(path),
        fit: studio ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const Center(child: PhosphorIcon(PhosphorIconsDuotone.image, size: 32, color: C.faint)),
      ),
    );
    if (aspect != null) img = AspectRatio(aspectRatio: aspect!, child: img);
    return radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: img) : img;
  }
}

class SaveButton extends ConsumerWidget {
  const SaveButton(this.id, {super.key, this.size = 34});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider).contains(id);
    return Pressable(
      onTap: () {
        final added = ref.read(savedProvider.notifier).toggle(id);
        showToast(context, added ? 'Saved to your wishlist' : 'Removed from wishlist', icon: added ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart);
      },
      scale: .88,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), shape: BoxShape.circle, boxShadow: softShadow(.1)),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: PhosphorIcon(
              saved ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
              key: ValueKey(saved),
              size: size * .55,
              color: saved ? C.error : C.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Status badge shown on listing images.
Widget listingBadge(Listing l) {
  if (l.isRealEstate) {
    final type = l.specs['Listing type'];
    return switch (type) {
      'For rent' => const ImageBadge('For Rent'),
      'For lease' => const ImageBadge('For Lease'),
      _ => const ImageBadge('For Sale', bg: C.green),
    };
  }
  if (l.isFeatured) return const ImageBadge('Featured');
  if (l.seller.sold >= 100) return const ImageBadge('Top Seller', bg: C.primaryDark);
  if (l.condition == Condition.brandNew) return const ImageBadge('Brand New', bg: C.green);
  return const SizedBox.shrink();
}

/// Shop grid card: image with badge and heart, title, location, price and
/// one clear action. Property opens "Contact Seller" (never paid in app).
class ListingCard extends ConsumerWidget {
  const ListingCard(this.l, {super.key, this.showAction = true});
  final Listing l;
  final bool showAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref.watch(cartProvider).contains(l.id);
    final sold = l.status == ListingStatus.sold;
    final rentPeriod = l.pricePeriod;
    return Pressable(
      onTap: () => context.push('/item/${l.id}'),
      scale: .98,
      child: Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.card), border: Border.all(color: C.border), boxShadow: softShadow(.04)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1.22,
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'img-${l.id}', child: ProductImage(l.images.first)),
              Positioned(left: 8, top: 8, child: listingBadge(l)),
              Positioned(right: 8, top: 8, child: SaveButton(l.id, size: 30)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800)),
              const Gap(4),
              Row(children: [
                const PhosphorIcon(PhosphorIconsRegular.mapPin, size: 12.5, color: C.muted),
                const HGap(3),
                Expanded(child: Text('${l.area}, ${l.city}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: C.muted, fontSize: 11.5))),
              ]),
              const Gap(6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: money(l.price)),
                  if (rentPeriod != null) TextSpan(text: ' ${rentPeriod.replaceFirst('Per ', '/')}', style: T.caption.copyWith(color: C.primary, fontWeight: FontWeight.w700)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.moneyOf(16, w: FontWeight.w800, color: C.primary),
              ),
              if (showAction) ...[
                const Gap(9),
                _CardAction(
                  label: sold ? 'Sold' : (l.isRealEstate ? 'Contact Seller' : (inCart ? 'In Cart' : 'Add to Cart')),
                  icon: l.isRealEstate ? PhosphorIconsRegular.phone : (inCart ? PhosphorIconsBold.check : PhosphorIconsRegular.shoppingCart),
                  bg: l.isRealEstate ? C.tint : C.mint,
                  fg: l.isRealEstate ? C.primary : const Color(0xFF14532D),
                  onTap: sold
                      ? null
                      : () {
                          if (l.isRealEstate) {
                            showAppSheet<void>(context, builder: (_) => ContactSellerSheet(l));
                          } else if (inCart) {
                            context.push('/cart');
                          } else {
                            ref.read(cartProvider.notifier).add(l.id);
                            showToast(context, 'Added to cart', icon: PhosphorIconsFill.shoppingCart);
                          }
                        },
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.icon, required this.bg, required this.fg, this.onTap});
  final String label;
  final PhosphorIconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .5 : 1,
          child: Container(
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PhosphorIcon(icon, size: 15, color: fg),
              const HGap(6),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.label.copyWith(color: fg, fontSize: 12.5, fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      );
}

/// Responsive 2-column grid used on Home, Market, Saved, Seller profile.
class ListingGrid extends StatelessWidget {
  const ListingGrid(this.items, {super.key, this.padding = const EdgeInsets.symmetric(horizontal: Sp.page)});
  final List<Listing> items;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final l in items) SizedBox(width: w, child: ListingCard(l))]);
      }),
    );
  }
}
