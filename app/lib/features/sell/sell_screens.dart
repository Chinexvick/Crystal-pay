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
import '../../core/utils/pick_photos.dart';
import '../../data/account.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../market/item_screens.dart';
import '../market/listing_card.dart';
import '../orders/orders_screens.dart';
import 'plans_screen.dart';
import 'insights_screen.dart';
import '../../data/plans.dart';

class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});
  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

const _maxPhotos = 5;

class _SellScreenState extends ConsumerState<SellScreen> {
  final List<String> _photos = [];
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  String _cat = categories.first.id;
  Condition _cond = Condition.used;
  bool _negotiable = true, _delivery = true, _pickup = true;
  String _state = 'Lagos';
  String _area = 'Yaba';
  bool _publishing = false;
  String? _publishedId;

  // Real-estate answers. Buyers never pay for these on the platform.
  String _reMode = 'For sale';
  String _rePeriod = 'Per year';
  String _reType = 'House';
  String _reBeds = '3';
  String _reBaths = '2';
  String _reFurnish = 'Unfurnished';
  String _reParking = 'Yes';
  String _reTitle = 'C of O';
  // Land-only answers.
  String _landMode = 'For sale';
  String _landUse = 'Residential';
  String _landFenced = 'Yes';
  String _landRoad = 'Tarred';
  String _landTopo = 'Dry land';
  final _reSize = TextEditingController();
  final _reAddress = TextEditingController();

  bool get _re => propertyCategories.contains(_cat);
  bool get _land => _cat == 'lands';
  bool get _rent => _land ? _landMode == 'For lease' : _reMode == 'For rent';

  @override
  void dispose() {
    _reSize.dispose();
    _reAddress.dispose();
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  int get _priceV => int.tryParse(_price.text.replaceAll(',', '')) ?? 0;

  bool get _valid {
    final base = _photos.isNotEmpty && _title.text.trim().length >= 4 && _desc.text.trim().length >= 10 && _priceV > 0;
    if (_re) return base && (int.tryParse(_reSize.text.trim()) ?? 0) > 0;
    return base && (_delivery || _pickup);
  }

  Map<String, String> get _reSpecs => _land
      ? {
          'Listing type': _landMode,
          if (_landMode == 'For lease') 'Lease is paid': 'Per year',
          'Land use': _landUse,
          'Plot size': '${_reSize.text.trim()} sqm',
          'Fenced': _landFenced,
          'Access road': _landRoad,
          'Topography': _landTopo,
          'Title / documents': _reTitle,
          if (_reAddress.text.trim().isNotEmpty) 'Street / estate': _reAddress.text.trim(),
        }
      : {
          'Listing type': _reMode,
          if (_reMode == 'For rent') 'Rent is paid': _rePeriod,
          'Property type': _reType,
          'Bedrooms': _reBeds,
          'Bathrooms': _reBaths,
          'Size': '${_reSize.text.trim()} sqm',
          'Furnishing': _reFurnish,
          'Parking': _reParking,
          'Title / documents': _reTitle,
          if (_reAddress.text.trim().isNotEmpty) 'Street / estate': _reAddress.text.trim(),
        };

  Future<void> _addPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) {
      showToast(context, 'You can add up to $_maxPhotos photos', error: true);
      return;
    }
    final got = await pickPhotos(context, max: room);
    if (got.isEmpty || !mounted) return;
    setState(() => _photos.addAll(got.where((g) => !_photos.contains(g)).take(room)));
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    setState(() => _publishing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final me = ref.read(accountProvider);
    final id = 'u${DateTime.now().millisecondsSinceEpoch}';
    ref.read(listingsProvider.notifier).add(Listing(
      id: id,
      title: _title.text.trim(),
      price: _priceV,
      negotiable: _negotiable,
      condition: _cond,
      categoryId: _cat,
      images: List.of(_photos),
      city: _state.split(' ').first,
      area: _area,
      seller: Seller(id: 'me', name: me.fullName, avatar: me.photo, rating: 0, reviews: 0, verified: me.idVerified, city: me.city, joined: 'Joined today', sold: 0),
      description: _desc.text.trim(),
      postedAt: DateTime.now(),
      delivery: _re ? false : _delivery,
      pickup: _re ? false : _pickup,
      specs: _re ? _reSpecs : const {},
      contactPhone: me.phone,
    ));
    HapticFeedback.mediumImpact();
    setState(() {
      _publishing = false;
      _publishedId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_publishedId != null) return _Published(id: _publishedId!, onAnother: () => context.pushReplacement('/sell'));
    final acct = ref.watch(accountProvider);
    final used = ref.watch(activeListingCountProvider);
    if (!acct.planActive) return const PlanBlock(noPlan: true, limit: 0);
    final plan = planById(acct.plan!);
    if (used >= plan.listingLimit) return PlanBlock(noPlan: false, limit: plan.listingLimit, planName: plan.name);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: _re ? (_land ? 'List a Land' : 'List a Property') : 'Post an Item'),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 24), children: [
            _Section('Photos (up to $_maxPhotos)', child: _photoStrip()),
            const Gap(14),
            _Section(_re ? 'Listing details' : 'Item details', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppTextField(controller: _title, label: 'Title', hint: _re ? (_land ? 'e.g. 600 sqm plot, Ibeju-Lekki' : 'e.g. 3 bedroom flat, Yaba') : 'e.g. iPhone X 64GB, clean', maxLength: 70, onChanged: (_) => setState(() {})),
              const Gap(16),
              Text('Category', style: T.label),
              const Gap(10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in categories) _CatChip(c, _cat == c.id, () => setState(() => _cat = c.id)),
              ]),
              if (!_re) ...[
                const Gap(18),
                Text('Condition', style: T.label),
                const Gap(10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in Condition.values) _Pill(c.label, _cond == c, () => setState(() => _cond = c)),
                ]),
              ],
              const Gap(18),
              AppTextField(controller: _desc, label: 'Description', hint: _re ? 'Describe the property, the area, access and anything a buyer should know' : 'Describe the item, its age, any faults and what is included', maxLines: 5, maxLength: 500, onChanged: (_) => setState(() {})),
            ])),
            const Gap(14),
            if (_re) ...[
              _Section(_land ? 'Land details' : 'Property details', child: _land ? _landForm() : _realEstateForm()),
              const Gap(14),
            ],
            _Section('Price', child: Column(children: [
              AmountField(controller: _price, hint: _re ? (_rent ? (_land ? 'Lease per year' : 'Rent amount') : 'Asking price') : 'Asking price', onChanged: (_) => setState(() {})),
              const Gap(6),
              _SwitchRow('Price is negotiable', 'Buyers can send you offers', _negotiable, (v) => setState(() => _negotiable = v)),
            ])),
            const Gap(14),
            _Section(_re ? 'Location' : 'Location and handover', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _Dropdown(value: _state, items: ngStates.keys.toList(), onChanged: (v) => setState(() {
                  _state = v;
                  _area = ngStates[v]!.first;
                }))),
                const HGap(10),
                Expanded(child: _Dropdown(value: _area, items: ngStates[_state]!, onChanged: (v) => setState(() => _area = v))),
              ]),
              if (!_re) ...[
              const Gap(10),
              _SwitchRow('Delivery', 'Buyer pays ${money(kDeliveryFee)} delivery fee', _delivery, (v) => setState(() => _delivery = v)),
              _SwitchRow('Pickup', 'Buyer collects from you', _pickup, (v) => setState(() => _pickup = v)),
              if (!_delivery && !_pickup) const Padding(padding: EdgeInsets.only(top: 6), child: InfoBanner('Choose at least one handover option.', kind: BannerKind.error)),
              ],
            ])),
            const Gap(14),
            if (_re)
              const InfoBanner('Houses and land are never paid for on Crystal Pay. Interested buyers will see your phone number and chat so you agree details with them directly. Never ask anyone to pay you through the app.', kind: BannerKind.warning)
            else
              InfoBanner('${plan.name} plan: ${used + 1} of ${plan.listingLimit} listings after this post. ${_fee(plan.serviceFeePct)}% service fee is deducted when your item sells.'),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
          child: AppButton(label: _re ? 'Publish Listing' : 'Post Item', loading: _publishing, onPressed: _valid ? _publish : null),
        ),
      ]),
    );
  }

  static String _fee(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _opts(String label, List<String> items, String value, ValueChanged<String> on) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.label),
        const Gap(10),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final i in items) _Pill(i, value == i, () => setState(() => on(i)))]),
        const Gap(18),
      ]);

  Widget _realEstateForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _opts('Is it for sale or rent?', const ['For sale', 'For rent'], _reMode, (v) => _reMode = v),
        if (_reMode == 'For rent') _opts('Rent is paid', const ['Per year', 'Per month', 'Per night'], _rePeriod, (v) => _rePeriod = v),
        _opts('Property type', const ['House', 'Duplex', 'Bungalow', 'Apartment / flat', 'Commercial', 'Shortlet'], _reType, (v) => _reType = v),
        _opts('Bedrooms', const ['1', '2', '3', '4', '5', '6+'], _reBeds, (v) => _reBeds = v),
        _opts('Bathrooms', const ['1', '2', '3', '4', '5+'], _reBaths, (v) => _reBaths = v),
        AppTextField(controller: _reSize, label: 'Size (sqm)', hint: 'e.g. 450', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {})),
        const Gap(18),
        _opts('Furnishing', const ['Unfurnished', 'Semi-furnished', 'Furnished'], _reFurnish, (v) => _reFurnish = v),
        _opts('Parking space', const ['Yes', 'No'], _reParking, (v) => _reParking = v),
        _opts('Title / documents', const ['C of O', 'Deed of assignment', "Governor's consent", 'Survey plan', 'Receipt only', 'None yet'], _reTitle, (v) => _reTitle = v),
        AppTextField(controller: _reAddress, label: 'Street or estate (optional)', hint: 'e.g. Admiralty Way, Lekki Phase 1', onChanged: (_) => setState(() {})),
      ]);

  Widget _landForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _opts('Is it for sale or lease?', const ['For sale', 'For lease'], _landMode, (v) => _landMode = v),
        _opts('Land use', const ['Residential', 'Commercial', 'Mixed use', 'Agricultural'], _landUse, (v) => _landUse = v),
        AppTextField(controller: _reSize, label: 'Plot size (sqm)', hint: 'e.g. 600 (one plot is about 600 sqm in Lagos)', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {})),
        const Gap(18),
        _opts('Is it fenced?', const ['Yes', 'Partly', 'No'], _landFenced, (v) => _landFenced = v),
        _opts('Access road', const ['Tarred', 'Untarred', 'None yet'], _landRoad, (v) => _landRoad = v),
        _opts('Topography', const ['Dry land', 'Partly wet', 'Swampy'], _landTopo, (v) => _landTopo = v),
        _opts('Title / documents', const ['C of O', 'Deed of assignment', "Governor's consent", 'Survey plan', 'Excision / gazette', 'Receipt only'], _reTitle, (v) => _reTitle = v),
        AppTextField(controller: _reAddress, label: 'Street or estate (optional)', hint: 'e.g. Eleko Junction, Ibeju-Lekki', onChanged: (_) => setState(() {})),
      ]);

  Widget _photoStrip() {
    const size = 92.0;
    return SizedBox(
      height: size + 4,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var i = 0; i < _photos.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: ProductImage(_photos[i], forceCover: true)),
                if (i == 0)
                  Positioned(left: 6, bottom: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(6)), child: Text('Cover', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10.5)))),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Pressable(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xCC0B1F5C), shape: BoxShape.circle), child: const Center(child: PhosphorIcon(PhosphorIconsBold.x, size: 12, color: Colors.white))),
                  ),
                ),
              ]),
            ),
          ),
        if (_photos.length < _maxPhotos)
          Pressable(
            onTap: _addPhotos,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.primary.withValues(alpha: .4))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const PhosphorIcon(PhosphorIconsDuotone.camera, size: 28, color: C.primary),
                const Gap(4),
                Text(_photos.isEmpty ? 'Add photos' : 'Add more', style: T.caption.copyWith(color: C.primary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.title),
          const Gap(12),
          child,
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.sel, this.onTap);
  final String label;
  final bool sel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: sel ? C.tint : C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: sel ? C.primary : C.border, width: sel ? 1.4 : 1)),
          child: Text(label, style: T.label.copyWith(color: sel ? C.primary : C.muted)),
        ),
      );
}

class _CatChip extends StatelessWidget {
  const _CatChip(this.c, this.sel, this.onTap);
  final Category c;
  final bool sel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(color: sel ? C.tint : C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: sel ? C.primary : C.border, width: sel ? 1.4 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon3D(c.id, size: 26),
            const SizedBox(width: 6),
            Text(categoryShort(c), style: T.label.copyWith(color: sel ? C.primary : C.ink)),
          ]),
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(this.title, this.sub, this.value, this.onChanged);
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.title),
              Text(sub, style: T.small),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.input), border: Border.all(color: C.border)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const PhosphorIcon(PhosphorIconsBold.caretDown, size: 14, color: C.muted),
            style: T.bodyM,
            borderRadius: BorderRadius.circular(14),
            items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}

class _Published extends StatelessWidget {
  const _Published({required this.id, required this.onAnother});
  final String id;
  final VoidCallback onAnother;
  @override
  Widget build(BuildContext context) {
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
              child: const Center(child: PhosphorIcon(PhosphorIconsFill.storefront, size: 48, color: Colors.white)),
            ),
            const Gap(26),
            Text('Your listing is live', style: T.h1),
            const Gap(8),
            Text('Buyers across Nigeria can now see your item.\nWe will notify you about offers and messages.', style: T.small.copyWith(fontSize: 14), textAlign: TextAlign.center),
            const Spacer(),
            AppButton(label: 'View listing', onPressed: () => context.pushReplacement('/item/$id')),
            const Gap(10),
            AppButton(label: 'Sell another item', kind: BtnKind.soft, onPressed: onAnother),
            const Gap(10),
            TextLink('Back to home', trailing: false, onTap: () => context.go('/home')),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── My listings ─────────────────────────

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});
  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(myListingsProvider);
    final st = [ListingStatus.active, ListingStatus.sold, ListingStatus.draft][_tab];
    final list = all.where((l) => l.status == st).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'My Listings', actions: [RoundIconButton(icon: PhosphorIconsBold.chartBar, size: 38, onTap: () => context.push('/insights')), const HGap(8), RoundIconButton(icon: PhosphorIconsBold.plus, bg: C.primary, fg: Colors.white, size: 38, onTap: () => context.push('/sell'))]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 14),
          child: SegmentedToggle2(options: const ['Active', 'Sold', 'Drafts'], index: _tab, onChanged: (v) => setState(() => _tab = v)),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(icon: PhosphorIconsDuotone.storefront, title: 'Nothing here', message: _tab == 0 ? 'List an item and it will appear here.' : 'Items will show here once they match this tab.', actionLabel: _tab == 0 ? 'Sell an item' : null, onAction: () => context.push('/sell'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Gap(12),
                  itemBuilder: (_, i) => _MyCard(list[i]),
                ),
        ),
      ]),
    );
  }
}

class _MyCard extends ConsumerWidget {
  const _MyCard(this.l);
  final Listing l;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sold = l.status == ListingStatus.sold;
    return AppCard(
      onTap: () => context.push('/item/${l.id}'),
      child: Column(children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 76, height: 76, child: ProductImage(l.images.first))),
          const HGap(14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, style: T.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const Gap(4),
              Text(money(l.price), style: T.moneyOf(16, color: C.primary)),
              const Gap(4),
              Row(children: [
                const PhosphorIcon(PhosphorIconsRegular.eye, size: 13, color: C.faint),
                Text(' ${l.views}', style: T.caption),
                const HGap(12),
                const PhosphorIcon(PhosphorIconsRegular.heart, size: 13, color: C.faint),
                Text(' ${l.saves}', style: T.caption),
              ]),
            ]),
          ),
        ]),
        const Gap(12),
        Row(children: [
          Expanded(child: AppButton(label: 'Price', kind: BtnKind.soft, small: true, onPressed: () => showEditPriceSheet(context, ref, l))),
          const HGap(8),
          if (!sold) ...[
            Expanded(child: AppButton(label: l.isBoosted ? 'Boosted' : 'Boost', kind: BtnKind.soft, small: true, onPressed: () => showBoostSheet(context, ref, l))),
            const HGap(8),
          ],
          Expanded(
            child: AppButton(
              label: sold ? 'Relist' : 'Sold',
              kind: BtnKind.soft,
              small: true,
              onPressed: () => ref.read(listingsProvider.notifier).setStatus(l.id, sold ? ListingStatus.active : ListingStatus.sold),
            ),
          ),
          const HGap(8),
          Pressable(
            onTap: () async {
              final ok = await showAppSheet<bool>(context, builder: (ctx) => SheetFrame(
                title: 'Delete listing?',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('"${l.title}" will be removed permanently.', style: T.small.copyWith(fontSize: 13.5)),
                  const Gap(20),
                  AppButton(label: 'Delete', kind: BtnKind.danger, onPressed: () => Navigator.pop(ctx, true)),
                ]),
              ));
              if (ok == true) {
                ref.read(listingsProvider.notifier).remove(l.id);
                if (context.mounted) showToast(context, 'Listing deleted');
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.errorTint, shape: BoxShape.circle),
              child: const Center(child: PhosphorIcon(PhosphorIconsRegular.trash, size: 18, color: C.error)),
            ),
          ),
        ]),
      ]),
    );
  }
}
