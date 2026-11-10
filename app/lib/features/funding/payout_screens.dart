import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../data/account.dart';
import '../../core/config/app_config.dart';
import '../../core/security/idempotency.dart';
import '../../core/security/validators.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/state.dart';
import '../../services/mock_services.dart';
import '../../services/models.dart';
import '../../services/providers.dart';
import '../bills/bill_common.dart';

// ───────────────────────── Bank picker ─────────────────────────

Future<Bank?> showBankPicker(BuildContext context) => showAppSheet<Bank>(context, builder: (_) => const _BankPicker());

class _BankPicker extends ConsumerStatefulWidget {
  const _BankPicker();
  @override
  ConsumerState<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends ConsumerState<_BankPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(banksProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * .8,
      child: SheetFrame(
        title: 'Select bank',
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .8 - 80,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 10),
              child: AppTextField(hint: 'Search banks', prefix: const Padding(padding: EdgeInsets.only(left: 14, right: 4), child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: C.muted)), onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
            ),
            Expanded(
              child: banks.when(
                loading: () => const Center(child: CircularProgressIndicator(color: C.primary)),
                error: (_, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not load banks'),
                  const Gap(8),
                  TextLink('Retry', trailing: false, onTap: () => ref.invalidate(banksProvider)),
                ])),
                data: (list) {
                  final f = list.where((b) => b.name.toLowerCase().contains(_q)).toList();
                  if (f.isEmpty) return const Center(child: Text('No bank found'));
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 24),
                    itemCount: f.length,
                    itemBuilder: (_, i) => Pressable(
                      onTap: () => Navigator.pop(context, f[i]),
                      scale: .99,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          BankLogo(code: f[i].code, name: f[i].name, size: 40),
                          const HGap(14),
                          Expanded(child: Text(f[i].name, style: T.bodyM)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Accounts ─────────────────────────

Future<PayoutAccount?> showAccountsSheet(BuildContext context, {String? selectedId}) => showAppSheet<PayoutAccount>(context, builder: (_) => _AccountsSheet(selectedId: selectedId));

class _AccountsSheet extends ConsumerWidget {
  const _AccountsSheet({this.selectedId});
  final String? selectedId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(payoutAccountsProvider);
    return SheetFrame(
      title: 'Choose bank account',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final a in list)
          Pressable(
            onTap: () => Navigator.pop(context, a),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                BankLogo(code: a.bank.code, name: a.bank.name, size: 44),
                const HGap(14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.accountName, style: T.title.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${a.bank.name} · ${maskAccount(a.accountNumber)}', style: T.small),
                  ]),
                ),
                RadioDot(selected: a.id == selectedId),
              ]),
            ),
          ),
        const Gap(8),
        AppButton(
          label: 'Add new bank account',
          kind: BtnKind.soft,
          icon: PhosphorIconsBold.plus,
          onPressed: () async {
            final added = await showAppSheet<PayoutAccount>(context, builder: (_) => const _AddAccountSheet());
            if (added != null && context.mounted) Navigator.pop(context, added);
          },
        ),
      ]),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();
  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

enum _Resolve { idle, loading, ok, mismatch, notFound, error }

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  Bank? _bank;
  final _num = TextEditingController();
  _Resolve _state = _Resolve.idle;
  ResolvedAccount? _res;
  int _seq = 0;

  @override
  void dispose() {
    _num.dispose();
    super.dispose();
  }

  Future<void> _maybeResolve() async {
    final n = _num.text;
    if (_bank == null || !isValidAccountNumber(n)) {
      setState(() {
        _state = _Resolve.idle;
        _res = null;
      });
      return;
    }
    final my = ++_seq;
    setState(() => _state = _Resolve.loading);
    try {
      final r = await ref.read(bankServiceProvider).resolve(bankCode: _bank!.code, accountNumber: n);
      if (!mounted || my != _seq) return;
      setState(() {
        _res = r;
        _state = namesMatch(r.accountName, ref.read(accountProvider).fullName) ? _Resolve.ok : _Resolve.mismatch;
      });
    } on AccountNotFound {
      if (mounted && my == _seq) setState(() => _state = _Resolve.notFound);
    } catch (_) {
      if (mounted && my == _seq) setState(() => _state = _Resolve.error);
    }
  }

  Future<void> _save() async {
    final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: 0, title: 'Confirm new account', subtitle: 'Enter your PIN to add ${_res!.bank.name} ${maskAccount(_res!.accountNumber)}'));
    if (pin != true || !mounted) return;
    final acct = PayoutAccount(id: 'pa_${newIdempotencyKey().substring(0, 8)}', bank: _res!.bank, accountNumber: _res!.accountNumber, accountName: _res!.accountName);
    ref.read(payoutAccountsProvider.notifier).add(acct);
    Navigator.pop(context, acct);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Add bank account',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppTextField(
          controller: TextEditingController(text: _bank?.name ?? ''),
          label: 'Bank',
          hint: 'Select bank',
          readOnly: true,
          suffix: const Padding(padding: EdgeInsets.all(14), child: PhosphorIcon(PhosphorIconsBold.caretDown, size: 16, color: C.muted)),
          onTap: () async {
            final b = await showBankPicker(context);
            if (b != null) {
              setState(() => _bank = b);
              _maybeResolve();
            }
          },
        ),
        const Gap(14),
        AppTextField(
          controller: _num,
          label: 'Account number',
          hint: '10 digits',
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => _maybeResolve(),
        ),
        const Gap(14),
        switch (_state) {
          _Resolve.idle => const SizedBox.shrink(),
          _Resolve.loading => const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: C.primary)), HGap(10), Text('Verifying account…')]),
          _Resolve.ok => _NameBox(name: _res!.accountName, ok: true),
          _Resolve.mismatch => Column(children: [
              _NameBox(name: _res!.accountName, ok: false),
              const Gap(10),
              InfoBanner('The account name must match your verified name (${ref.read(accountProvider).fullName.toUpperCase()}). Withdrawals to other people’s accounts are not allowed.', kind: BannerKind.error),
            ]),
          _Resolve.notFound => const InfoBanner('We could not find that account. Check the number and bank.', kind: BannerKind.error),
          _Resolve.error => const InfoBanner('Could not verify the account right now. Try again.', kind: BannerKind.warning),
        },
        const Gap(20),
        AppButton(label: 'Verify & save', onPressed: _state == _Resolve.ok ? _save : null),
      ]),
    );
  }
}

class _NameBox extends StatelessWidget {
  const _NameBox({required this.name, required this.ok});
  final String name;
  final bool ok;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ok ? C.tint : C.errorTint, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          PhosphorIcon(ok ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle, size: 22, color: ok ? C.primary : C.error),
          const HGap(10),
          Expanded(child: Text(name, style: T.title.copyWith(color: ok ? C.primary : C.error))),
        ]),
      );
}

// ───────────────────────── Withdraw (Naira only) ─────────────────────────

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});
  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _naira = TextEditingController();
  PayoutAccount? _acct;

  @override
  void initState() {
    super.initState();
    final l = ref.read(payoutAccountsProvider);
    if (l.isNotEmpty) _acct = l.first;
  }

  @override
  void dispose() {
    _naira.dispose();
    super.dispose();
  }

  int? get _n => parseNaira(_naira.text);

  String? _nairaErr(num bal, num sentToday) {
    if (_naira.text.isEmpty) return null;
    final v = _n;
    if (v == null) return 'Enter a valid amount';
    if (v < Limits.minWithdrawNaira) return 'Minimum is ${money(Limits.minWithdrawNaira)}';
    if (v > Limits.maxWithdrawNaira) return 'Maximum is ${money(Limits.maxWithdrawNaira)} per withdrawal';
    if (v + Fees.withdrawNaira > bal) return 'Insufficient balance (fee ${money(Fees.withdrawNaira)})';
    if (sentToday + v > Limits.dailyOutNaira) return 'Daily limit of ${money(Limits.dailyOutNaira)} reached';
    return null;
  }

  Future<void> _pickAccount() async {
    final a = await showAccountsSheet(context, selectedId: _acct?.id);
    if (a != null) setState(() => _acct = a);
  }

  Future<void> _submitNaira() async {
    final amt = _n!;
    final a = _acct!;
    final ok = await showAppSheet<bool>(context, builder: (_) => _ConfirmSheet(title: 'Confirm withdrawal', hero: money2(amt), rows: [
          ('To', a.accountName),
          ('Bank', a.bank.name),
          ('Account', maskAccount(a.accountNumber)),
          ('Fee', money2(Fees.withdrawNaira)),
          ('Total debit', money2(amt + Fees.withdrawNaira)),
        ]));
    if (ok != true || !mounted) return;
    final pin = await showAppSheet<bool>(context, builder: (_) => PinSheet(amount: amt + Fees.withdrawNaira, title: 'Enter transaction PIN', subtitle: 'Withdraw ${money2(amt)} to ${a.bank.name} ${maskAccount(a.accountNumber)}'));
    if (pin != true || !mounted) return;
    showDialog<void>(context: context, barrierDismissible: false, barrierColor: C.scrim, builder: (_) => const ProcessingDialog());
    try {
      final r = await ref.read(payoutServiceProvider).withdrawNaira(amount: amt, account: a, idempotencyKey: newIdempotencyKey());
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final tx = ref.read(walletProvider.notifier).withdraw(amt, a.bank.name, fee: Fees.withdrawNaira, details: {'Account': maskAccount(a.accountNumber), 'Account name': a.accountName, 'Reference': r.reference});
      context.push('/pay/${tx.id}');
    } on InsufficientFunds {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showToast(context, 'Insufficient wallet balance', error: true);
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showToast(context, 'Withdrawal failed. You were not charged.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bal = ref.watch(walletProvider).balance;
    final sentToday = ref.watch(sentOutTodayProvider);
    final accounts = ref.watch(payoutAccountsProvider);
    final verified = ref.watch(accountProvider).idVerified;
    if (_acct != null && !accounts.any((x) => x.id == _acct!.id)) _acct = accounts.isEmpty ? null : accounts.first;
    final nErr = _nairaErr(bal, sentToday);
    final canNaira = verified && _acct != null && _n != null && nErr == null;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Withdraw'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 32), children: [
        if (!verified) ...[
          InfoBanner('Verify your identity to withdraw. It confirms the bank account is really yours.', kind: BannerKind.warning, action: 'Verify now', onAction: () => context.push('/settings/verify-id')),
          const Gap(16),
        ],
        Text('Send to', style: T.title),
        const Gap(10),
        _AccountCard(acct: _acct, onTap: _pickAccount),
        const Gap(20),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Amount', style: T.title),
              const Spacer(),
              Text('Balance ${money2(bal)}', style: T.small),
            ]),
            const Gap(12),
            AmountField(controller: _naira, hint: 'Amount in Naira', onChanged: (_) => setState(() {}), error: nErr),
            const Gap(12),
            Row(children: [
              for (final p in const [25, 50, 100]) ...[
                Expanded(
                  child: Pressable(
                    onTap: () => setState(() {
                      final v = ((bal - Fees.withdrawNaira) * p / 100).floor();
                      _naira.text = v > 0 ? '$v' : '';
                    }),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(p == 100 ? 'Max' : '$p%', style: T.label.copyWith(color: C.primary)),
                    ),
                  ),
                ),
                if (p != 100) const HGap(8),
              ],
            ]),
            const Gap(14),
            KvRow('Fee', money2(Fees.withdrawNaira)),
            KvRow('Daily limit left', money(Limits.dailyOutNaira - sentToday)),
          ]),
        ),
        const Gap(22),
        AppButton(label: 'Continue', onPressed: canNaira ? _submitNaira : null),
        const Gap(14),
        Center(child: Text('Withdrawals only go to accounts in your own verified name.', style: T.caption, textAlign: TextAlign.center)),
      ]),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.acct, required this.onTap});
  final PayoutAccount? acct;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = acct;
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        if (a == null) const IconChip(PhosphorIconsDuotone.bank, size: 46) else BankLogo(code: a.bank.code, name: a.bank.name, size: 46),
        const HGap(14),
        Expanded(
          child: a == null
              ? Text('Add a bank account', style: T.title)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.accountName, style: T.title.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${a.bank.name} · ${maskAccount(a.accountNumber)}', style: T.small),
                ]),
        ),
        a == null ? Text('Add', style: T.label.copyWith(color: C.primary)) : const PhosphorIcon(PhosphorIconsBold.caretDown, size: 16, color: C.muted),
      ]),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.title, required this.hero, required this.rows});
  final String title, hero;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Text(hero, style: T.moneyOf(36))),
        const Gap(18),
        AppCard(color: C.bg, borderColor: null, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: [for (final r in rows) KvRow(r.$1, r.$2)])),
        const Gap(18),
        AppButton(label: 'Confirm', onPressed: () => Navigator.pop(context, true)),
        const Gap(8),
        AppButton(label: 'Cancel', kind: BtnKind.soft, onPressed: () => Navigator.pop(context, false)),
      ]),
    );
  }
}
