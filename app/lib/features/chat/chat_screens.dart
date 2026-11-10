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
import '../market/item_screens.dart';
import '../market/listing_card.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider).where((c) => c.messages.isNotEmpty).toList()..sort((a, b) => b.last.time.compareTo(a.last.time));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Messages'),
      body: chats.isEmpty
          ? EmptyState(icon: PhosphorIconsDuotone.chatCircleDots, title: 'No messages yet', message: 'Chat with sellers about items you like.', actionLabel: 'Browse market', onAction: () => context.go('/shop'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 32),
              itemCount: chats.length,
              separatorBuilder: (_, _) => const Gap(10),
              itemBuilder: (_, i) {
                final c = chats[i];
                return AppCard(
                  onTap: () => context.push('/chat/${c.id}'),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Avatar(asset: c.seller.avatar, name: c.seller.name, size: 52, verified: c.seller.verified),
                    const HGap(12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.seller.name, style: T.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text(timeAgo(c.last.time), style: T.caption),
                        ]),
                        const Gap(2),
                        Text(c.listing.title, style: T.caption.copyWith(color: C.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const Gap(3),
                        Row(children: [
                          Expanded(child: Text(c.last.text, style: T.small.copyWith(color: c.unread > 0 ? C.ink : C.muted, fontWeight: c.unread > 0 ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (c.unread > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(10)),
                              child: Text('${c.unread}', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ]),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatsProvider.notifier).markRead(widget.id));
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    ref.read(chatsProvider.notifier).send(widget.id, t);
    _c.clear();
    simulateReply(ref, widget.id);
    _toEnd();
  }

  void _toEnd() => Future.delayed(const Duration(milliseconds: 120), () {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(chatsProvider).where((c) => c.id == widget.id).firstOrNull;
    if (t == null) return const Scaffold(body: SizedBox());
    ref.listen(chatsProvider, (_, _) => _toEnd());
    final l = t.listing;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(
        title: t.seller.name,
        divider: true,
        actions: [Avatar(asset: t.seller.avatar, name: t.seller.name, size: 34)],
      ),
      body: Column(children: [
        Pressable(
          onTap: () => context.push('/item/${l.id}'),
          child: Container(
            color: C.surface,
            padding: const EdgeInsets.fromLTRB(Sp.page, 10, Sp.page, 10),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 44, height: 44, child: ProductImage(l.images.first))),
              const HGap(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, style: T.title.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(money(l.price), style: T.moneyOf(13.5, color: C.primary)),
                ]),
              ),
              if (l.status == ListingStatus.active && l.seller.id != 'me') AppButton(label: 'Buy', small: true, expand: false, onPressed: () => context.push('/checkout/${l.id}')),
            ]),
          ),
        ),
        const HairDivider(),
        Expanded(
          child: t.messages.isEmpty
              ? Center(child: Text('Say hello to ${t.seller.name.split(' ').first}', style: T.small.copyWith(fontSize: 14)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Sp.page, 16, Sp.page, 12),
                  itemCount: t.messages.length,
                  itemBuilder: (_, i) => _Bubble(t.messages[i]),
                ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Sp.page), children: [
            for (final q in const ['Is this still available?', 'What is your last price?', 'Can we meet today?', 'Can you deliver?'])
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: Pressable(
                  onTap: () => _send(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(999)),
                    child: Text(q, style: T.label.copyWith(color: C.primary, fontSize: 12.5)),
                  ),
                ),
              ),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Sp.page, 8, 12, 10 + MediaQuery.of(context).padding.bottom),
          color: C.surface,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  filled: true,
                  fillColor: C.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                ),
              ),
            ),
            const HGap(8),
            Pressable(
              onTap: () => _send(_c.text),
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(gradient: C.brandGradient, shape: BoxShape.circle),
                child: const Center(child: PhosphorIcon(PhosphorIconsFill.paperPlaneTilt, size: 21, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);
  final Msg m;
  @override
  Widget build(BuildContext context) {
    final mine = m.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .74),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? C.primary : C.surface,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)),
          border: mine ? null : Border.all(color: C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (m.offer != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const PhosphorIcon(PhosphorIconsBold.handshake, size: 15, color: Colors.white),
                const HGap(6),
                Text('Offer ${money(m.offer!)}', style: T.label.copyWith(color: Colors.white)),
              ]),
            ),
          Align(alignment: Alignment.centerLeft, widthFactor: 1, child: Text(m.text, style: T.body.copyWith(color: mine ? Colors.white : C.ink))),
          const Gap(3),
          Text(clock(m.time), style: T.caption.copyWith(color: mine ? Colors.white70 : C.faint, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ───────────────────────── Notifications ─────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  (PhosphorIconData, Color, Color) _style(NoteKind k) => switch (k) {
        NoteKind.bill => (PhosphorIconsDuotone.receipt, C.primary, C.tint),
        NoteKind.order => (PhosphorIconsDuotone.package, C.violet, C.violetTint),
        NoteKind.offer => (PhosphorIconsDuotone.handshake, C.primary, C.tint),
        NoteKind.wallet => (PhosphorIconsDuotone.wallet, C.primary, C.tint),
        NoteKind.promo => (PhosphorIconsDuotone.gift, C.pending, C.goldTint),
        NoteKind.security => (PhosphorIconsDuotone.shieldCheck, C.error, C.errorTint),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final unread = ref.watch(unreadNotesProvider);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Notifications', actionLabel: unread > 0 ? 'Mark all read' : null, onAction: () => ref.read(notesProvider.notifier).markAllRead()),
      body: notes.isEmpty
          ? const EmptyState(icon: PhosphorIconsDuotone.bell, title: 'All caught up', message: 'New alerts about your orders and payments show up here.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 32),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const Gap(10),
              itemBuilder: (_, i) {
                final n = notes[i];
                final (ic, fg, bg) = _style(n.kind);
                return AppCard(
                  onTap: () {
                    ref.read(notesProvider.notifier).markRead(n.id);
                    final route = switch (n.kind) { NoteKind.order || NoteKind.offer => '/orders', NoteKind.wallet || NoteKind.bill => '/transactions', _ => null };
                    if (route != null) context.push(route);
                  },
                  color: n.read ? C.surface : C.tint2,
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconChip(ic, size: 44, bg: bg, fg: fg, circle: true, iconSize: 22),
                    const HGap(12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(n.title, style: T.title.copyWith(fontSize: 14.5))),
                          if (!n.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle)),
                        ]),
                        const Gap(3),
                        Text(n.body, style: T.small.copyWith(fontSize: 13)),
                        const Gap(6),
                        Text(timeAgo(n.time), style: T.caption),
                      ]),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
