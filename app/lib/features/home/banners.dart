import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';

class _Slide {
  const _Slide({required this.line1, required this.line2, required this.sub, required this.cta, required this.route, required this.image, this.go = false});
  final String line1;
  final String line2;
  final String sub;
  final String cta;
  final String route;
  final String image;
  final bool go;
}

const _slides = <_Slide>[
  _Slide(
    line1: 'Find. Buy. Own.',
    line2: 'All in One Place.',
    sub: 'Shop great items, get lands and houses, and pay your bills with ease.',
    cta: 'Explore Now',
    route: '/shop',
    image: 'assets/illustrations/hero_market.webp',
    go: true,
  ),
  _Slide(
    line1: 'Add money',
    line2: 'your way.',
    sub: 'Fund your wallet by card, bank transfer or Crystal Cat token.',
    cta: 'Add Money',
    route: '/wallet/add',
    image: 'assets/illustrations/wallet_coins.webp',
  ),
  _Slide(
    line1: 'Houses and land',
    line2: 'near you.',
    sub: 'Browse verified sellers and agents, then talk to them directly.',
    cta: 'View Property',
    route: '/shop?cat=houses',
    image: 'assets/illustrations/property.webp',
    go: true,
  ),
  _Slide(
    line1: 'Turn items',
    line2: 'into cash.',
    sub: 'Post in minutes and reach buyers across Nigeria.',
    cta: 'Start Selling',
    route: '/sell',
    image: 'assets/illustrations/shop_bags.webp',
  ),
];

/// Home hero carousel: light lavender cards with 3D art, auto-advancing.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});
  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _pc = PageController();
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_i + 1) % _slides.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 196,
        child: PageView.builder(
          controller: _pc,
          itemCount: _slides.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.page),
            child: _HeroCard(_slides[i]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Dots(count: _slides.length, index: _i),
    ]);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(this.s);
  final _Slide s;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => s.go ? context.go(s.route) : context.push(s.route),
      scale: .985,
      child: Container(
        decoration: BoxDecoration(
          gradient: C.heroGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE6DCFB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, c) {
          final iw = c.maxWidth * .47;
          return Stack(children: [
            Positioned(
              right: -30,
              bottom: -40,
              child: Container(
                width: iw * 1.2,
                height: iw * 1.2,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDCCBFF).withValues(alpha: .55)),
              ),
            ),
            Positioned(right: 2, top: 10, bottom: 8, width: iw, child: Image.asset(s.image, fit: BoxFit.contain, filterQuality: FilterQuality.medium)),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 18, iw - 4, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.line1, maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: T.h2.copyWith(fontSize: 21, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -.6)),
                Text(s.line2, maxLines: 1, softWrap: false, style: T.h2.copyWith(fontSize: 21, fontWeight: FontWeight.w800, height: 1.15, color: C.primary, letterSpacing: -.6)),
                const SizedBox(height: 8),
                Expanded(child: Text(s.sub, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.small.copyWith(color: const Color(0xFF3B3555), fontSize: 12.5, height: 1.4))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: C.primaryDark, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.cta, style: T.label.copyWith(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const PhosphorIcon(PhosphorIconsBold.arrowRight, size: 13, color: Colors.white),
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
