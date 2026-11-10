import 'package:flutter/material.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import 'buttons.dart';
import 'common.dart';

/// The Crystal Pay "C" mark.
///
/// Placement rule (from Apple HIG / Material guidance): the logo appears on
/// the splash, welcome, sign-in, the home header and About only. Inner
/// screens identify themselves with their page title instead.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 32});
  final double height;
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/brand/logo_mark.webp', height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}

/// Mark + "Crystal Pay" wordmark ("Pay" in brand purple).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.height = 34, this.tagline, this.light = false});
  final double height;
  final String? tagline;
  final bool light;
  @override
  Widget build(BuildContext context) {
    final fs = height * .62;
    final ink = light ? Colors.white : C.ink;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(height: height),
      SizedBox(width: height * .22),
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Crystal ', style: TextStyle(color: ink)),
            TextSpan(text: 'Pay', style: TextStyle(color: light ? const Color(0xFFD9C8FF) : C.primary)),
          ]),
          style: TextStyle(fontFamily: T.family, fontSize: fs, fontWeight: FontWeight.w800, letterSpacing: -.5, height: 1.05),
        ),
        if (tagline != null)
          Text(tagline!, style: TextStyle(fontFamily: T.family, fontSize: fs * .42, fontWeight: FontWeight.w600, color: light ? Colors.white70 : C.primary, letterSpacing: .2, height: 1.3)),
      ]),
    ]);
  }
}

/// Large title header for the top-level tabs (Shop, Bills, More).
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: T.pageTitle)),
            for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 10), actions[i]],
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: T.small.copyWith(fontSize: 13.5, color: C.muted)),
          ],
        ]),
      ),
    );
  }
}

/// Header icon button with the soft lavender treatment used in the designs.
class HeaderIcon extends StatelessWidget {
  const HeaderIcon({super.key, required this.icon, this.onTap, this.badge, this.dot = false});
  final PhosphorIconData icon;
  final VoidCallback? onTap;
  final int? badge;
  final bool dot;
  @override
  Widget build(BuildContext context) =>
      RoundIconButton(icon: icon, onTap: onTap, badge: badge, dot: dot, bg: const Color(0xFFF3EFFB), fg: C.ink, size: 44);
}

/// Deep purple promo banner with a 3D illustration on the right.
class PromoBanner extends StatelessWidget {
  const PromoBanner({
    super.key,
    required this.title,
    required this.image,
    this.eyebrow,
    this.subtitle,
    this.cta,
    this.onTap,
    this.height = 168,
    this.leading,
    this.imageWidthFactor = .44,
  });
  final String title;
  final String image;
  final String? eyebrow;
  final String? subtitle;
  final String? cta;
  final VoidCallback? onTap;
  final double height;
  final Widget? leading;
  final double imageWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Container(
        height: height,
        decoration: BoxDecoration(gradient: C.bannerGradient, borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, c) {
          final iw = c.maxWidth * imageWidthFactor;
          return Stack(children: [
            // soft light behind the art
            Positioned(
              right: -40,
              top: -30,
              child: Container(
                width: iw * 1.3,
                height: iw * 1.3,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withValues(alpha: .22), Colors.white.withValues(alpha: 0)])),
              ),
            ),
            Positioned(right: 4, top: 6, bottom: 6, width: iw, child: Image.asset(image, fit: BoxFit.contain, filterQuality: FilterQuality.medium)),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 16, iw - 6, 16),
              child: Row(children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (eyebrow != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF8BE3AE), borderRadius: BorderRadius.circular(999)),
                        child: Text(eyebrow!, style: T.caption.copyWith(color: const Color(0xFF0E3B22), fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(title, maxLines: 3, style: T.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19, height: 1.15, letterSpacing: -.4)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.small.copyWith(color: Colors.white.withValues(alpha: .86), fontSize: 12.5)),
                    ],
                    if (cta != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(cta!, style: T.label.copyWith(color: C.primaryDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          const PhosphorIcon(PhosphorIconsBold.arrowRight, size: 13, color: C.primaryDark),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

/// Small rounded badge used on listing images ("Featured", "For Sale", …).
class ImageBadge extends StatelessWidget {
  const ImageBadge(this.text, {super.key, this.bg = C.primary, this.fg = Colors.white});
  final String text;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontFamily: T.family, color: fg, fontWeight: FontWeight.w700, fontSize: 10.5, height: 1.1)),
      );
}

/// Page indicator dots (active = purple pill).
class Dots extends StatelessWidget {
  const Dots({super.key, required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(color: i == index ? C.primary : const Color(0xFFDCD5EC), borderRadius: BorderRadius.circular(4)),
          ),
      ]);
}

/// Thin card section used for menu lists (white, rounded, hairline border).
class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => AppCard(onTap: onTap, padding: padding, radius: 18, child: child);
}
