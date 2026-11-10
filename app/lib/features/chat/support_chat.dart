import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/account.dart';

class _Msg {
  _Msg(this.text, {required this.fromMe, DateTime? at}) : at = at ?? DateTime.now();
  final String text;
  final bool fromMe;
  final DateTime at;
}

const _topics = <String, String>{
  'A payment failed': 'Sorry about that. If money left your wallet, it is returned automatically within 10 minutes. Please share the transaction reference from Transactions > the payment, and I will check it right away.',
  'Where is my order?': 'Open Me > My orders and tap the order to see its live status. If the seller has not shipped within 48 hours, you can cancel and your payment is refunded from Crystal Protect.',
  'Withdrawal issue': 'Withdrawals to your own verified bank account usually arrive within minutes. If it has been over 30 minutes, send me the amount and the bank, and I will trace it.',
  'Verify my identity': 'You can verify with your NIN, BVN or international passport from Me > Verify your identity. Your name must match the ID exactly. Which one are you using?',
  'Report a seller': 'I am sorry to hear that. Tell me the listing or the seller name and what happened. Please do not pay or send money outside Crystal Pay.',
};

/// Live support. Front-end only: replies are scripted until the support
/// backend (ticketing / chat provider) is connected.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});
  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  bool _typing = false;
  Timer? _t;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    final first = ref.read(accountProvider).firstName;
    _msgs.add(_Msg('Hi${first.isEmpty ? '' : ' $first'}, welcome to Crystal Pay support. How can I help you today?', fromMe: false));
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() => Future.delayed(const Duration(milliseconds: 120), () {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _msgs.add(_Msg(t, fromMe: true));
      _typing = true;
      _asked++;
    });
    _c.clear();
    _toEnd();
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final reply = _topics[t] ?? (_asked > 1
          ? 'Thanks, I have added that to your case. A support agent will reply here and by email within 15 minutes. Your ticket number is CP-${(10000 + t.length * 137 % 9000)}.'
          : 'Thanks for explaining. Can you share the transaction reference or order number, if you have one? It helps me find it quickly.');
      setState(() {
        _typing = false;
        _msgs.add(_Msg(reply, fromMe: false));
      });
      _toEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final showChips = _msgs.length == 1;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: '', divider: true, onBack: () => context.pop()),
      body: Column(children: [
        Container(
          color: C.surface,
          padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: C.tint, shape: BoxShape.circle),
              child: const BrandMark(height: 30),
            ),
            const HGap(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Crystal Pay Support', style: T.title),
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22A06B), shape: BoxShape.circle)),
                  const HGap(6),
                  Text('Online · replies in a few minutes', style: T.small.copyWith(fontSize: 12.5)),
                ]),
              ]),
            ),
          ]),
        ),
        const HairDivider(),
        Expanded(
          child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(Sp.page, 16, Sp.page, 12), children: [
            for (final m in _msgs) _SupportBubble(m),
            if (_typing) const _Typing(),
            if (showChips) ...[
              const Gap(8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final q in _topics.keys)
                  Pressable(
                    onTap: () => _send(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.primary.withValues(alpha: .5))),
                      child: Text(q, style: T.label.copyWith(color: C.primary, fontSize: 13)),
                    ),
                  ),
              ]),
            ],
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
                  hintText: 'Type your message',
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
              child: Container(width: 46, height: 46, decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle), child: const Center(child: PhosphorIcon(PhosphorIconsFill.paperPlaneTilt, size: 20, color: Colors.white))),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SupportBubble extends StatelessWidget {
  const _SupportBubble(this.m);
  final _Msg m;
  @override
  Widget build(BuildContext context) {
    final me = m.fromMe;
    final hh = m.at.hour % 12 == 0 ? 12 : m.at.hour % 12;
    final time = '$hh:${m.at.minute.toString().padLeft(2, '0')} ${m.at.hour >= 12 ? 'PM' : 'AM'}';
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: me ? C.primary : C.surface,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(me ? 18 : 4), bottomRight: Radius.circular(me ? 4 : 18)),
          border: me ? null : Border.all(color: C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Align(alignment: Alignment.centerLeft, child: Text(m.text, style: T.body.copyWith(color: me ? Colors.white : C.ink, fontSize: 14.5, height: 1.4))),
          const Gap(4),
          Text(time, style: T.caption.copyWith(color: me ? Colors.white70 : C.faint, fontSize: 10.5)),
        ]),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: const BoxDecoration(color: C.faint, shape: BoxShape.circle)),
          ]),
        ),
      );
}
