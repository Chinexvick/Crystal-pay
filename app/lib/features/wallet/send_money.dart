import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/security/idempotency.dart';
import '../../core/security/validators.dart';
import '../../core/utils/contacts.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/account.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../bills/bill_common.dart' show PinSheet, ProcessingDialog;

/// A Crystal Pay user who can receive money.
class PayUser {
  const PayUser(this.username, this.name, this.phone, {this.avatar, this.verified = true});
  final String username;
  final String name;
  final String phone;
  final String? avatar;
  final bool verified;
}

/// Demo directory until the user-lookup API exists (GET /users/lookup).
const payUsers = <PayUser>[
  PayUser('chijioke', 'Chijioke Obi', '08031112233', avatar: 'assets/images/avatars/chijioke.jpg'),
  PayUser('chinelo', 'Chinelo Adeyemi', '08094445566', avatar: 'assets/images/avatars/chinelo.jpg'),
  PayUser('amaka', 'Amaka Eze', '07067778899', avatar: 'assets/images/avatars/oluwatoyin.jpg'),
  PayUser('emeka', 'Emeka Nwosu', '08033334455', avatar: 'assets/images/avatars/lender.jpg'),
  PayUser('tola', 'Tola Bakare', '08120001122', avatar: 'assets/images/avatars/tola.jpg', verified: false),
  PayUser('john', 'John Okafor', '09055556677', avatar: 'assets/images/avatars/john.jpg'),
];

/// Finds a user by @username, phone number or email (username@crystalpay.app).
PayUser? findPayUser(String raw) {
  final q = raw.trim().toLowerCase();
  if (q.isEmpty) return null;
  final handle = q.startsWith('@') ? q.substring(1) : q;
  final phone = normaliseNgNumber(q);
  for (final u in payUsers) {
    if (u.username == handle) return u;
    if (phone != null && u.phone == phone) return u;
    if (isEmail(q) && q.split('@').first == u.username) return u;
  }
  return null;
}

/// Daily limit for wallet-to-wallet transfers by KYC tier.
int sendLimit(Account a) => a.idVerified ? 500000 : 50000;

class SendMoneyScreen extends ConsumerStatefulWidget {
  const SendMoneyScreen({super.key});
  @override
  ConsumerState<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends ConsumerState<SendMoneyScreen> {
  final _who = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PayUser? _to;
  bool _looking = false;
  String? _lookupError;
  final String _key = newIdempotencyKey();

  @override
  void dispose() {
    _who.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? value]) async {
    final q = (value ?? _who.text).trim();
    if (q.length < 3) return;
    setState(() {
      _looking = true;
      _lookupError = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final u = findPayUser(q);
    final me = ref.read(accountProvider);
    setState(() {
      _looking = false;
      if (u != null && u.username == me.username) {
        _to = null;
        _lookupError = 'You cannot send money to yourself.';
      } else {
        _to = u;
        _lookupError = u == null ? 'No Crystal Pay user found. Check the username, phone or email.' : null;
      }
    });
  }

  int? get _v => parseNaira(_amount.text);

  String? get _amountError {
    final v = _v;
    if (_amount.text.isEmpty || v == null) return null;
    final bal = ref.read(walletProvider).balance;
    if (v < 50) return 'Minimum is ₦50';
    if (v > bal) return 'More than your balance (${money(bal)})';
    if (v > sendLimit(ref.read(accountProvider))) return 'Above your limit of ${money(sendLimit(ref.read(accountProvider)))} per transfer';
    return null;
  }

  Future<void> _send() async {
    final to = _to!;
    final v = _v!;
    FocusScope.of(context).unfocus();
    final ok = await showAppSheet<bool>(context, builder: (_) => _ConfirmSheet(to: to, amount: v, note: _note.text.trim()));
    if (ok != true || !mounted) return;
    final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: v, title: 'Confirm with your PIN', subtitle: 'Send ${money(v)} to ${to.name}'));
    if (pin != true || !mounted) return;
    showDialog<void>(context: context, barrierDismissible: false, barrierColor: C.scrim, builder: (_) => const ProcessingDialog());
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    try {
      final tx = ref.read(walletProvider.notifier).pay(
            kind: TxKind.transfer,
            title: 'Sent to ${to.name}',
            subtitle: '@${to.username}',
            amount: v,
            details: {'Recipient': '${to.name} (@${to.username})', if (_note.text.trim().isNotEmpty) 'Note': _note.text.trim(), 'Reference': _key.substring(0, 12).toUpperCase()},
          );
      HapticFeedback.mediumImpact();
      if (mounted) context.pushReplacement('/pay/${tx.id}');
    } on InsufficientFunds {
      if (mounted) showToast(context, 'Not enough balance', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bal = ref.watch(walletProvider).balance;
    final recent = payUsers.take(4).toList();
    final canSend = _to != null && _v != null && _amountError == null;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Send Money'),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 6, Sp.page, 24), children: [
            Text('Send to any Crystal Pay user instantly and free.', style: T.small.copyWith(fontSize: 13.5)),
            const Gap(18),
            Text('Recent', style: T.label),
            const Gap(10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const HGap(14),
                itemBuilder: (_, i) {
                  final u = recent[i];
                  final sel = _to?.username == u.username;
                  return Pressable(
                    onTap: () {
                      _who.text = '@${u.username}';
                      setState(() {
                        _to = u;
                        _lookupError = null;
                      });
                    },
                    child: SizedBox(
                      width: 64,
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel ? C.primary : Colors.transparent, width: 2)),
                          child: Avatar(asset: u.avatar, name: u.name, size: 50, verified: u.verified),
                        ),
                        const Gap(6),
                        Text(u.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: C.ink, fontWeight: FontWeight.w700, fontSize: 11.5)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const Gap(16),
            AppTextField(
              controller: _who,
              label: 'Recipient',
              hint: '@username, phone or email',
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {
                _to = null;
                _lookupError = null;
              }),
              onSubmitted: _lookup,
              suffix: Pressable(
                onTap: () async {
                  final n = await pickPhoneContact(context);
                  if (n != null) {
                    _who.text = n;
                    _lookup(n);
                  }
                },
                child: const Padding(padding: EdgeInsets.all(12), child: PhosphorIcon(PhosphorIconsRegular.addressBook, size: 20, color: C.primary)),
              ),
            ),
            const Gap(10),
            if (_looking)
              Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const HGap(10),
                Text('Finding user…', style: T.small),
              ])
            else if (_to != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Avatar(asset: _to!.avatar, name: _to!.name, size: 40, verified: _to!.verified),
                  const HGap(12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_to!.name, style: T.title),
                      Text('@${_to!.username}', style: T.small),
                    ]),
                  ),
                  const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 22, color: C.success),
                ]),
              )
            else if (_lookupError != null)
              InfoBanner(_lookupError!, kind: BannerKind.error)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextLink('Find recipient', onTap: _who.text.trim().length >= 3 ? () => _lookup() : null),
              ),
            const Gap(18),
            AmountField(controller: _amount, hint: 'Amount', onChanged: (_) => setState(() {})),
            const Gap(6),
            Row(children: [
              Expanded(child: Text(_amountError ?? 'Balance: ${money2(bal)}', style: T.small.copyWith(color: _amountError != null ? C.error : C.muted))),
            ]),
            const Gap(14),
            AppTextField(controller: _note, label: 'Note (optional)', hint: 'What is it for?', maxLength: 60),
            const Gap(6),
            const InfoBanner('Only send money to people you know. Transfers between Crystal Pay wallets are instant and cannot be reversed.'),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
          child: AppButton(label: _v == null ? 'Continue' : 'Send ${money(_v!)}', onPressed: canSend ? _send : null),
        ),
      ]),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.to, required this.amount, required this.note});
  final PayUser to;
  final int amount;
  final String note;
  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Confirm Transfer',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Avatar(asset: to.avatar, name: to.name, size: 64, verified: to.verified)),
        const Gap(10),
        Center(child: Text(money2(amount), style: T.moneyOf(28))),
        const Gap(14),
        KvRow('To', to.name),
        KvRow('Username', '@${to.username}'),
        KvRow('Fee', 'Free'),
        if (note.isNotEmpty) KvRow('Note', note),
        const Gap(16),
        AppButton(label: 'Confirm and Send', onPressed: () => Navigator.pop(context, true)),
      ]),
    );
  }
}
