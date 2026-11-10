import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'bill_common.dart';

enum Verify { idle, loading, ok, error }

String _token() {
  final r = math.Random();
  return List.generate(5, (_) => (1000 + r.nextInt(9000)).toString()).join(' ');
}

/// Row of equally-sized provider tiles (TV / betting / internet).
class ProviderChips extends StatelessWidget {
  const ProviderChips({super.key, required this.items, required this.selectedId, required this.onTap, this.onMore});
  final List<Biller> items;
  final String selectedId;
  final ValueChanged<Biller> onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final b in items)
        Expanded(
          child: Pressable(
            onTap: () => onTap(b),
            haptic: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              decoration: BoxDecoration(color: b.id == selectedId ? C.tint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ProviderLogo(asset: b.asset, name: b.name, size: 48, color: b.color),
                const Gap(6),
                Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.smallM.copyWith(color: b.id == selectedId ? C.primary : C.ink, fontWeight: b.id == selectedId ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
                const Gap(6),
                AnimatedContainer(duration: const Duration(milliseconds: 180), width: b.id == selectedId ? 26 : 0, height: 3, decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(2))),
              ]),
            ),
          ),
        ),
      if (onMore != null)
        Expanded(
          child: Pressable(
            onTap: onMore,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.border, width: 1.6)), child: const Center(child: PhosphorIcon(PhosphorIconsBold.dotsThree, size: 22, color: C.muted))),
                const Gap(6),
                Text('More', style: T.smallM.copyWith(color: C.ink, fontSize: 12)),
                const Gap(9),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.controller, required this.onChanged, this.trailingLabel, this.onTrailing, required this.maxLen, this.hint, this.below, this.big = true});
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final int maxLen;
  final String? hint;
  final Widget? below;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: T.label.copyWith(fontSize: 14))),
          if (trailingLabel != null) TextLink(trailingLabel!, onTap: onTrailing, color: C.muted),
        ]),
        const Gap(6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLen)],
          onChanged: onChanged,
          cursorColor: C.primary,
          style: T.moneyOf(big ? 24 : 18, w: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint ?? 'Enter number',
            hintStyle: T.moneyOf(18, w: FontWeight.w500, color: C.border),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            isDense: true,
            suffixIcon: controller.text.isEmpty
                ? null
                : Pressable(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const PhosphorIcon(PhosphorIconsFill.xCircle, size: 18, color: C.faint),
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
        if (below != null) ...[const HGap(0), const HairDivider(), const Gap(12), below!],
      ]),
    );
  }
}

class _VerifyBlock extends StatelessWidget {
  const _VerifyBlock({required this.state, required this.name, this.error, this.extra});
  final Verify state;
  final String name;
  final String? error;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case Verify.idle:
        return const SizedBox.shrink();
      case Verify.loading:
        return Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: C.primary, strokeCap: StrokeCap.round)),
          const HGap(10),
          Text('Verifying…', style: T.small),
        ]);
      case Verify.error:
        return Row(children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 18, color: C.error),
          const HGap(8),
          Expanded(child: Text(error ?? 'Could not verify. Check the number and try again.', style: T.small.copyWith(color: C.error))),
        ]);
      case Verify.ok:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VerifiedName(name), if (extra != null) ...[const Gap(12), extra!]]);
    }
  }
}

// ───────────────────────── Electricity ─────────────────────────

class ElectricityScreen extends ConsumerStatefulWidget {
  const ElectricityScreen({super.key});
  @override
  ConsumerState<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends ConsumerState<ElectricityScreen> {
  Biller _disco = discos.firstWhere((d) => d.id == 'enugu');
  int _type = 0;
  final _meter = TextEditingController(text: '45031987266');
  final _amount = TextEditingController();
  Verify _v = Verify.idle;
  String _name = '';
  int _vid = 0;
  bool _voucher = true;
  bool _save = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _meter.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final id = ++_vid;
    final m = _meter.text;
    if (m.length < 11) {
      setState(() => _v = Verify.idle);
      return;
    }
    setState(() => _v = Verify.loading);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || id != _vid) return;
    setState(() {
      if (m == '00000000000') {
        _v = Verify.error;
      } else {
        _v = Verify.ok;
        _name = mockCustomerName(m);
      }
    });
  }

  int get _amt => int.tryParse(_amount.text) ?? 0;
  int get _min => _type == 0 ? 1000 : 500;
  int get _discount => _voucher && _amt >= 2000 ? 20 : 0;

  void _pay() {
    final token = _type == 0 ? _token() : null;
    final payable = _amt - _discount;
    startBillPayment(
      context,
      ref,
      BillRequest(
        kind: TxKind.electricity,
        productName: 'Electricity',
        provider: _disco,
        rows: [('Meter Number', _meter.text), ('Customer Name', _name), ('Account Type', _type == 0 ? 'Prepaid' : 'Postpaid'), ('Amount', money2(_amt))],
        amount: payable,
        discount: _discount,
        subtitle: '${_disco.name} · ${_type == 0 ? 'Prepaid' : 'Postpaid'}',
        token: token,
        details: {'Provider': _disco.name, 'Meter': _meter.text, 'Customer': _name, 'Type': _type == 0 ? 'Prepaid' : 'Postpaid', if (_type == 0) 'Units': '${(_amt / 70).toStringAsFixed(1)} kWh'},
        beneficiary: _save ? Beneficiary(id: 'b${DateTime.now().millisecondsSinceEpoch}', name: 'Meter ${_meter.text.substring(_meter.text.length - 4)}', value: _meter.text, kind: TxKind.electricity, billerId: _disco.id) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ok = _v == Verify.ok;
    return BillScaffold(
      title: 'Electricity',
      kind: TxKind.electricity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            onTap: () async {
              final b = await showProviderSheet(context, title: 'Select Provider', items: discos, selectedId: _disco.id);
              if (b != null) {
                setState(() => _disco = b);
                _verify();
              }
            },
            child: Row(children: [
              ProviderLogo(asset: _disco.asset, name: _disco.name, size: 46),
              const HGap(14),
              Expanded(child: Text(_disco.name, style: T.h3.copyWith(fontSize: 18))),
              const PhosphorIcon(PhosphorIconsBold.caretRight, size: 16, color: C.faint),
            ]),
          ),
          const Gap(12),
          SegmentedToggle(options: const ['Prepaid', 'Postpaid'], index: _type, onChanged: (i) => setState(() => _type = i)),
          const Gap(12),
          _FieldCard(
            label: 'Meter / Account Number',
            controller: _meter,
            maxLen: 13,
            hint: 'Enter meter number',
            trailingLabel: 'Beneficiaries',
            onTrailing: () async {
              final b = await showBeneficiarySheet(context, kind: TxKind.electricity);
              if (b != null) {
                _meter.text = b.value;
                final d = discos.where((x) => x.id == b.billerId);
                if (d.isNotEmpty) _disco = d.first;
                _verify();
              }
            },
            onChanged: (_) {
              setState(() {});
              _verify();
            },
            below: _meter.text.length < 11
                ? null
                : _VerifyBlock(
                    state: _v,
                    name: _name,
                    error: 'Meter not found for ${_disco.name}. Check the number and try again.',
                    extra: _type == 0
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
                            child: Column(children: [
                              KvRow('Min Purchase', '1,000', bold: true),
                              KvRow('Service Address', '${_name.split(' ').first.substring(0, math.min(4, _name.split(' ').first.length))}******', bold: true),
                            ]),
                          )
                        : null,
                  ),
          ),
          if (ok) ...[
            const Gap(12),
            SaveBeneficiaryRow(value: _save, onChanged: (v) => setState(() => _save = v)),
          ],
          const Gap(12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () async {
              final r = await showAppSheet<bool>(
                context,
                builder: (ctx) => SheetFrame(
                  title: 'Vouchers',
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.tint2, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.primary.withValues(alpha: .25))),
                      child: Row(children: [
                        const IconChip(PhosphorIconsDuotone.ticket, size: 44),
                        const HGap(12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('₦20 electricity voucher', style: T.title),
                            const Gap(2),
                            Text('Min. spend ₦2,000 · expires in 5 days', style: T.small),
                          ]),
                        ),
                        RadioDot(selected: _voucher),
                      ]),
                    ),
                    const Gap(16),
                    AppButton(label: _voucher ? 'Remove voucher' : 'Apply voucher', kind: _voucher ? BtnKind.soft : BtnKind.primary, onPressed: () => Navigator.pop(ctx, !_voucher)),
                  ]),
                ),
              );
              if (r != null) setState(() => _voucher = r);
            },
            child: Row(children: [
              const IconChip(PhosphorIconsDuotone.ticket, size: 38, bg: C.goldTint, fg: C.pending),
              const HGap(12),
              Text('Voucher', style: T.title),
              const HGap(8),
              const Tag('₦20', bg: C.tint, fg: C.primary),
              const Spacer(),
              Text(_voucher ? 'Applied' : 'More', style: T.small),
              const HGap(2),
              const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
            ]),
          ),
          const Gap(12),
          AmountCard(
            title: _type == 0 ? 'Select Amount' : 'Amount',
            quick: _type == 0 ? const [1000, 2000, 3000, 5000, 10000, 20000] : const [],
            controller: _amount,
            selected: _amt,
            subtitleOf: (a) => 'Pay ${money(a - (_voucher && a >= 2000 ? 20 : 0))}',
            min: _min,
            max: 500000,
            hint: 'Enter Amount',
            payEnabled: ok,
            showGrid: _type == 0,
            error: _v == Verify.error ? null : null,
            onChanged: (_) => setState(() {}),
            onPay: _pay,
          ),
          if (!ok) ...[
            const Gap(10),
            Text('Verify your meter number to continue.', textAlign: TextAlign.center, style: T.small),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Betting ─────────────────────────

class BettingScreen extends ConsumerStatefulWidget {
  const BettingScreen({super.key});
  @override
  ConsumerState<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends ConsumerState<BettingScreen> {
  Biller _p = bettingProviders.first;
  Biller? _extra;
  final _uid = TextEditingController(text: '30482291');
  final _amount = TextEditingController();
  bool _save = false;

  @override
  void dispose() {
    _uid.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _amt => int.tryParse(_amount.text) ?? 0;

  void _pay() {
    startBillPayment(
      context,
      ref,
      BillRequest(
        kind: TxKind.betting,
        productName: 'Betting',
        provider: _p,
        rows: [('Account Number', _uid.text), ('Amount', money2(_amt))],
        amount: _amt,
        subtitle: '${_p.name} · ${_uid.text}',
        details: {'Provider': _p.name, 'User ID': _uid.text},
        beneficiary: _save ? Beneficiary(id: 'b${DateTime.now().millisecondsSinceEpoch}', name: 'My ${_p.name}', value: _uid.text, kind: TxKind.betting, billerId: _p.id) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = [bettingProviders[0], bettingProviders[1], _extra ?? bettingProviders[2]];
    return BillScaffold(
      title: 'Betting',
      kind: TxKind.betting,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: ProviderChips(
              items: shown,
              selectedId: _p.id,
              onTap: (b) => setState(() => _p = b),
              onMore: () async {
                final b = await showProviderSheet(context, title: 'Select Provider', items: bettingProviders, selectedId: _p.id);
                if (b != null) {
                  setState(() {
                    _p = b;
                    _extra = bettingProviders.take(3).contains(b) ? null : b;
                  });
                }
              },
            ),
          ),
          const Gap(12),
          _FieldCard(
            label: 'User ID',
            controller: _uid,
            maxLen: 14,
            hint: 'Enter your ${_p.name} ID',
            trailingLabel: 'Beneficiaries',
            onTrailing: () async {
              final b = await showBeneficiarySheet(context, kind: TxKind.betting);
              if (b != null) setState(() => _uid.text = b.value);
            },
            onChanged: (_) => setState(() {}),
            big: false,
          ),
          const Gap(12),
          SaveBeneficiaryRow(value: _save, onChanged: (v) => setState(() => _save = v)),
          const Gap(14),
          AmountCard(
            title: 'Select Amount',
            quick: const [100, 200, 300, 400, 500, 1000],
            controller: _amount,
            selected: _amt,
            min: 100,
            max: 1000000,
            hint: '100 – 1,000,000',
            payEnabled: _uid.text.length >= 6,
            onChanged: (_) => setState(() {}),
            onPay: _pay,
          ),
          const Gap(12),
          const InfoBanner('Betting wallets are credited instantly. Please gamble responsibly — 18+ only.', kind: BannerKind.warning),
        ],
      ),
    );
  }
}

// ───────────────────────── TV & Internet (bundle pickers) ─────────────────────────

class _BundleScreen extends ConsumerStatefulWidget {
  const _BundleScreen({required this.title, required this.kind, required this.providers, required this.bundles, required this.idLabel, required this.idHint, required this.idLen, required this.prefill, required this.cardNoun});
  final String title;
  final TxKind kind;
  final List<Biller> providers;
  final Map<String, List<Bundle>> bundles;
  final String idLabel;
  final String idHint;
  final int idLen;
  final String prefill;
  final String cardNoun;

  @override
  ConsumerState<_BundleScreen> createState() => _BundleScreenState();
}

class _BundleScreenState extends ConsumerState<_BundleScreen> {
  late Biller _p = widget.providers.first;
  late final TextEditingController _id = TextEditingController(text: widget.prefill);
  Verify _v = Verify.idle;
  String _name = '';
  int _vid = 0;
  int? _sel;
  bool _save = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final id = ++_vid;
    if (_id.text.length < widget.idLen) {
      setState(() => _v = Verify.idle);
      return;
    }
    setState(() => _v = Verify.loading);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || id != _vid) return;
    setState(() {
      if (_id.text == '0000000000') {
        _v = Verify.error;
      } else {
        _v = Verify.ok;
        _name = mockCustomerName(_id.text);
      }
    });
  }

  List<Bundle> get _list => widget.bundles[_p.id] ?? const [];

  void _pay() {
    final b = _list[_sel!];
    startBillPayment(
      context,
      ref,
      BillRequest(
        kind: widget.kind,
        productName: widget.title,
        provider: _p,
        rows: [(widget.cardNoun, _id.text), ('Customer Name', _name), ('Package', b.name), ('Amount', money2(b.price))],
        amount: b.price,
        cashback: (b.price * .01 * 100).round() / 100,
        subtitle: '${_p.name} · ${b.name}',
        details: {'Provider': _p.name, widget.cardNoun: _id.text, 'Package': b.name},
        beneficiary: _save ? Beneficiary(id: 'b${DateTime.now().millisecondsSinceEpoch}', name: '${_p.name} ${_id.text.substring(_id.text.length - 3)}', value: _id.text, kind: widget.kind, billerId: _p.id) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ok = _v == Verify.ok;
    final b = _sel == null || _sel! >= _list.length ? null : _list[_sel!];
    return BillScaffold(
      title: widget.title,
      kind: widget.kind,
      bottom: Container(
        padding: EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total', style: T.small),
              Text(b == null ? '—' : money2(b.price), style: T.moneyOf(20)),
            ]),
          ),
          SizedBox(width: 160, child: AppButton(label: 'Pay', onPressed: ok && b != null ? _pay : null)),
        ]),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: ProviderChips(
              items: widget.providers,
              selectedId: _p.id,
              onTap: (b) => setState(() {
                _p = b;
                _sel = null;
              }),
            ),
          ),
          const Gap(12),
          _FieldCard(
            label: widget.idLabel,
            controller: _id,
            maxLen: widget.idLen,
            hint: widget.idHint,
            trailingLabel: 'Beneficiaries',
            onTrailing: () async {
              final x = await showBeneficiarySheet(context, kind: widget.kind);
              if (x != null) {
                _id.text = x.value;
                _verify();
              }
            },
            onChanged: (_) {
              setState(() {});
              _verify();
            },
            below: _id.text.length < widget.idLen
                ? null
                : _VerifyBlock(
                    state: _v,
                    name: _name,
                    error: 'We could not find that ${widget.cardNoun.toLowerCase()}. Check and try again.',
                    extra: widget.kind == TxKind.tv
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
                            child: Column(children: [
                              KvRow('Current package', _list.isEmpty ? '—' : _list.first.name, bold: true),
                              const KvRow('Renewal date', '28 Oct 2026', bold: true),
                            ]),
                          )
                        : null,
                  ),
          ),
          if (ok) ...[const Gap(12), SaveBeneficiaryRow(value: _save, onChanged: (v) => setState(() => _save = v))],
          const Gap(18),
          Text('Select package', style: T.h3),
          const Gap(12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < _list.length; i++)
                Pressable(
                  onTap: () => setState(() => _sel = i),
                  scale: .99,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(border: i == _list.length - 1 ? null : const Border(bottom: BorderSide(color: C.border))),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_list[i].name, style: T.title),
                          if (_list[i].detail.isNotEmpty) ...[const Gap(2), Text(_list[i].detail, style: T.small)],
                        ]),
                      ),
                      Text(money(_list[i].price), style: T.moneyOf(15, w: FontWeight.w700, color: _sel == i ? C.primary : C.ink)),
                      const HGap(12),
                      RadioDot(selected: _sel == i),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class TvScreen extends StatelessWidget {
  const TvScreen({super.key});
  @override
  Widget build(BuildContext context) => _BundleScreen(title: 'TV', kind: TxKind.tv, providers: tvProviders, bundles: tvBundles, idLabel: 'Smartcard / IUC Number', idHint: 'Enter smartcard number', idLen: 10, prefill: '7000123456', cardNoun: 'Smartcard');
}

class InternetScreen extends StatelessWidget {
  const InternetScreen({super.key});
  @override
  Widget build(BuildContext context) => _BundleScreen(title: 'Internet', kind: TxKind.internet, providers: internetProviders, bundles: internetBundles, idLabel: 'Account / Device ID', idHint: 'Enter account or device ID', idLen: 10, prefill: '', cardNoun: 'Account');
}
