import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'listing_card.dart';

enum SortBy { newest, priceLow, priceHigh }

class ListingFilter {
  const ListingFilter({this.category, this.query = '', this.min, this.max, this.conditions = const {}, this.state, this.sort = SortBy.newest, this.negotiableOnly = false});
  final String? category;
  final String query;
  final int? min;
  final int? max;
  final Set<Condition> conditions;
  final String? state;
  final SortBy sort;
  final bool negotiableOnly;

  ListingFilter copyWith({Object? category = _keep, String? query, Object? min = _keep, Object? max = _keep, Set<Condition>? conditions, Object? state = _keep, SortBy? sort, bool? negotiableOnly}) => ListingFilter(
        category: identical(category, _keep) ? this.category : category as String?,
        query: query ?? this.query,
        min: identical(min, _keep) ? this.min : min as int?,
        max: identical(max, _keep) ? this.max : max as int?,
        conditions: conditions ?? this.conditions,
        state: identical(state, _keep) ? this.state : state as String?,
        sort: sort ?? this.sort,
        negotiableOnly: negotiableOnly ?? this.negotiableOnly,
      );

  static const _keep = Object();

  int get activeCount => (min != null || max != null ? 1 : 0) + (conditions.isNotEmpty ? 1 : 0) + (state != null ? 1 : 0) + (negotiableOnly ? 1 : 0);

  List<Listing> apply(List<Listing> all) {
    final q = query.trim().toLowerCase();
    final out = all.where((l) {
      if (category != null && l.categoryId != category) return false;
      if (q.isNotEmpty && !(l.title.toLowerCase().contains(q) || l.description.toLowerCase().contains(q) || categoryById(l.categoryId).name.toLowerCase().contains(q))) return false;
      if (min != null && l.price < min!) return false;
      if (max != null && l.price > max!) return false;
      if (conditions.isNotEmpty && !conditions.contains(l.condition)) return false;
      if (state != null && !(l.city.toLowerCase().contains(state!.split(' ').first.toLowerCase()))) return false;
      if (negotiableOnly && !l.negotiable) return false;
      return true;
    }).toList();
    switch (sort) {
      case SortBy.newest:
        out.sort((a, b) => b.postedAt.compareTo(a.postedAt));
      case SortBy.priceLow:
        out.sort((a, b) => a.price.compareTo(b.price));
      case SortBy.priceHigh:
        out.sort((a, b) => b.price.compareTo(a.price));
    }
    return out;
  }
}

Future<ListingFilter?> showFilterSheet(BuildContext context, ListingFilter initial) {
  return showAppSheet<ListingFilter>(context, builder: (_) => _FilterSheet(initial: initial));
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final ListingFilter initial;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListingFilter f = widget.initial;
  late final _min = TextEditingController(text: f.min?.toString() ?? '');
  late final _max = TextEditingController(text: f.max?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Widget _pill(String label, bool sel, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: sel ? C.tint : C.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: sel ? C.primary : Colors.transparent, width: 1.3)),
          child: Text(label, style: T.label.copyWith(color: sel ? C.primary : C.muted)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Filters',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Price range', style: T.label),
        const Gap(10),
        Row(children: [
          Expanded(child: AppTextField(controller: _min, hint: 'Min ₦', keyboard: TextInputType.number, fill: C.bg, formatters: [FilteringTextInputFormatter.digitsOnly])),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–', style: TextStyle(color: C.faint))),
          Expanded(child: AppTextField(controller: _max, hint: 'Max ₦', keyboard: TextInputType.number, fill: C.bg, formatters: [FilteringTextInputFormatter.digitsOnly])),
        ]),
        const Gap(22),
        Text('Condition', style: T.label),
        const Gap(10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in Condition.values)
            _pill(c.label, f.conditions.contains(c), () {
              final s = {...f.conditions};
              s.contains(c) ? s.remove(c) : s.add(c);
              setState(() => f = f.copyWith(conditions: s));
            }),
        ]),
        const Gap(22),
        Text('Location', style: T.label),
        const Gap(10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _pill('Anywhere', f.state == null, () => setState(() => f = f.copyWith(state: null))),
          for (final s in ngStates.keys) _pill(s, f.state == s, () => setState(() => f = f.copyWith(state: s))),
        ]),
        const Gap(22),
        Row(children: [
          Expanded(child: Text('Negotiable only', style: T.label)),
          Switch.adaptive(value: f.negotiableOnly, activeTrackColor: C.primary, onChanged: (v) => setState(() => f = f.copyWith(negotiableOnly: v))),
        ]),
        const Gap(18),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Reset',
              kind: BtnKind.soft,
              onPressed: () => Navigator.pop(context, ListingFilter(category: f.category, query: f.query, sort: f.sort)),
            ),
          ),
          const HGap(12),
          Expanded(flex: 2, child: AppButton(label: 'Show results', onPressed: () => Navigator.pop(context, f.copyWith(min: int.tryParse(_min.text), max: int.tryParse(_max.text))))),
        ]),
      ]),
    );
  }
}

Future<SortBy?> showSortSheet(BuildContext context, SortBy current) {
  const labels = {SortBy.newest: 'Newest first', SortBy.priceLow: 'Price: low to high', SortBy.priceHigh: 'Price: high to low'};
  return showAppSheet<SortBy>(
    context,
    builder: (ctx) => SheetFrame(
      title: 'Sort by',
      child: Column(children: [
        for (final e in labels.entries)
          Pressable(
            onTap: () => Navigator.pop(ctx, e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
              child: Row(children: [
                Expanded(child: Text(e.value, style: T.title.copyWith(color: e.key == current ? C.primary : C.ink, fontWeight: e.key == current ? FontWeight.w700 : FontWeight.w500))),
                if (e.key == current) const PhosphorIcon(PhosphorIconsBold.check, size: 18, color: C.primary),
              ]),
            ),
          ),
      ]),
    ),
  );
}

// ───────────────────────── Market tab ─────────────────────────

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key, this.initialCategory});
  final String? initialCategory;
  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  late ListingFilter _f = ListingFilter(category: widget.initialCategory);
  final _selChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Bring a pre-selected category chip (e.g. from Home) into view.
    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _selChip.currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: .5, duration: const Duration(milliseconds: 300));
      });
    }
  }

  Future<void> _openFilters() async {
    final r = await showFilterSheet(context, _f);
    if (r != null) setState(() => _f = r);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(feedProvider);
    final items = _f.apply(all);
    final cartCount = ref.watch(cartProvider).length;
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: Pressable(
        onTap: () => context.push('/sell'),
        haptic: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(gradient: C.brandGradient, borderRadius: BorderRadius.circular(999), boxShadow: softShadow(.25)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const PhosphorIcon(PhosphorIconsBold.plus, size: 18, color: Colors.white),
            const HGap(6),
            Text('Sell', style: T.button.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: TabHeader(
            title: 'Shop',
            subtitle: 'Discover amazing products and properties',
            actions: [
              HeaderIcon(icon: PhosphorIconsRegular.chatCircleDots, badge: ref.watch(unreadChatsProvider), onTap: () => context.push('/chats')),
              HeaderIcon(icon: PhosphorIconsRegular.shoppingCart, badge: cartCount, onTap: () => context.push('/cart')),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 16, Sp.page, 0),
            child: Row(children: [
              Expanded(
                child: Pressable(
                  onTap: () => context.push('/search'),
                  scale: .99,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFFF1EEF8), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: C.muted),
                      const HGap(10),
                      Expanded(child: Text('Search for items, lands or houses…', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(color: C.faint))),
                    ]),
                  ),
                ),
              ),
              const HGap(10),
              Pressable(
                onTap: _openFilters,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: _f.activeCount > 0 ? C.primary : const Color(0xFFF1EEF8), borderRadius: BorderRadius.circular(16)),
                    child: Center(child: PhosphorIcon(PhosphorIconsBold.slidersHorizontal, size: 20, color: _f.activeCount > 0 ? Colors.white : C.ink)),
                  ),
                  if (_f.activeCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: C.gold, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 2)),
                        child: Center(child: Text('${_f.activeCount}', style: const TextStyle(fontFamily: T.family, fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white))),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Sp.page, 14, Sp.page, 6),
              itemCount: categories.length + 1,
              separatorBuilder: (_, _) => const HGap(8),
              itemBuilder: (_, i) {
                final cat = i == 0 ? null : categories[i - 1];
                final sel = (cat?.id) == _f.category;
                return Pressable(
                  key: sel ? _selChip : null,
                  onTap: () => setState(() => _f = _f.copyWith(category: cat?.id)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.fromLTRB(cat == null ? 14 : 8, 0, 14, 0),
                    decoration: BoxDecoration(
                      color: sel ? C.primary : C.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sel ? C.primary : C.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (cat == null)
                        PhosphorIcon(PhosphorIconsBold.shoppingCart, size: 16, color: sel ? Colors.white : C.primary)
                      else
                        Icon3D(cat.id, size: 26),
                      const HGap(6),
                      Text(cat == null ? 'All' : categoryShort(cat), style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : C.ink)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 12),
            child: Row(children: [
              Expanded(child: Text('${items.length} ${items.length == 1 ? 'result' : 'results'}${_f.category == null ? '' : ' in ${categoryById(_f.category!).name}'}', style: T.smallM)),
              _MiniBtn(
                icon: PhosphorIconsBold.arrowsDownUp,
                label: switch (_f.sort) { SortBy.newest => 'Newest', SortBy.priceLow => 'Price: Low', SortBy.priceHigh => 'Price: High' },
                onTap: () async {
                  final s = await showSortSheet(context, _f.sort);
                  if (s != null) setState(() => _f = _f.copyWith(sort: s));
                },
              ),
            ]),
          ),
        ),
        if (_f.category != null && propertyCategories.contains(_f.category))
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 12),
              child: InfoBanner('Property is never paid for in the app. Contact the seller to inspect and agree terms directly.', kind: BannerKind.warning),
            ),
          ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(icon: PhosphorIconsDuotone.magnifyingGlass, title: 'No items found', message: 'Try removing a filter or searching for something else.', actionLabel: 'Clear Filters', onAction: () => setState(() => _f = const ListingFilter())),
          )
        else
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 96), child: ListingGrid(items))),
      ]),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.label, required this.onTap});
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  static const active = false;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: active ? C.tint : C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? C.primary : C.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PhosphorIcon(icon, size: 14, color: active ? C.primary : C.ink),
          const HGap(6),
          Text(label, style: T.label.copyWith(fontSize: 12.5, color: active ? C.primary : C.ink)),
        ]),
      ),
    );
  }
}

// ───────────────────────── Search ─────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _c = TextEditingController();
  ListingFilter _f = const ListingFilter();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit(String q) {
    ref.read(searchHistoryProvider.notifier).add(q);
    setState(() => _f = _f.copyWith(query: q));
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);
    final searching = _c.text.trim().isNotEmpty;
    final results = _f.copyWith(query: _c.text).apply(ref.watch(feedProvider));
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, Sp.page, 8),
            child: Row(children: [
              Pressable(onTap: () => context.pop(), child: const SizedBox(width: 46, height: 46, child: Center(child: PhosphorIcon(PhosphorIconsBold.caretLeft, size: 21)))),
              Expanded(
                child: TextField(
                  controller: _c,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _submit,
                  cursorColor: C.primary,
                  style: T.bodyM.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search for items, lands or houses…',
                    prefixIcon: const Padding(padding: EdgeInsets.only(left: 14, right: 8), child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: C.muted)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: searching
                        ? Pressable(
                            onTap: () => setState(_c.clear),
                            child: const Padding(padding: EdgeInsets.all(12), child: PhosphorIcon(PhosphorIconsFill.xCircle, size: 18, color: C.faint)),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: searching
                ? (results.isEmpty
                    ? EmptyState(icon: PhosphorIconsDuotone.magnifyingGlass, title: 'No results for “${_c.text.trim()}”', message: 'Check the spelling or try a more general term.')
                    : ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                        Padding(padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 12), child: Text('${results.length} results', style: T.smallM)),
                        ListingGrid(results),
                      ]))
                : ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 28), children: [
                    if (history.isNotEmpty) ...[
                      Row(children: [
                        Expanded(child: Text('Recent searches', style: T.h3)),
                        TextLink('Clear', onTap: () => ref.read(searchHistoryProvider.notifier).clear(), trailing: false),
                      ]),
                      const Gap(10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final h in history)
                          Pressable(
                            onTap: () {
                              _c.text = h;
                              _submit(h);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.border)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const PhosphorIcon(PhosphorIconsRegular.clockCounterClockwise, size: 14, color: C.faint),
                                const HGap(6),
                                Text(h, style: T.label.copyWith(color: C.ink)),
                              ]),
                            ),
                          ),
                      ]),
                      const Gap(26),
                    ],
                    Text('Browse categories', style: T.h3),
                    const Gap(12),
                    LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - 12) / 2;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        for (final cat in categories)
                          SizedBox(
                            width: w,
                            child: AppCard(
                              onTap: () => context.go('/shop?cat=${cat.id}'),
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                IconTile(cat.id, size: 42, bg: C.tint),
                                const HGap(10),
                                Expanded(child: Text(cat.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.smallM.copyWith(color: C.ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
                              ]),
                            ),
                          ),
                      ]);
                    }),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Saved ─────────────────────────

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);
    final items = ref.watch(listingsProvider).where((l) => saved.contains(l.id)).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Favorites'),
      body: items.isEmpty
          ? EmptyState(icon: PhosphorIconsDuotone.heart, title: 'Nothing saved yet', message: 'Tap the heart on any listing to keep it here for later.', actionLabel: 'Browse Shop', onAction: () => context.go('/shop'))
          : ListView(padding: const EdgeInsets.only(top: 8, bottom: 28), children: [ListingGrid(items)]),
    );
  }
}
