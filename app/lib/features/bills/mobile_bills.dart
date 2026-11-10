import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog.dart';
import '../../data/account.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'bill_common.dart';

// ───────────────────────── Airtime ─────────────────────────

class AirtimeScreen extends ConsumerStatefulWidget {
  const AirtimeScreen({super.key});
  @override
  ConsumerState<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends ConsumerState<AirtimeScreen> {
  late final _phone = TextEditingController(text: ref.read(accountProvider).phone);
  final _amount = TextEditingController();
  late String _net = detectNetwork(ref.read(accountProvider).phone) ?? 'mtn';
  bool _save = false;

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _phoneOk => isNgPhone(_phone.text);
  int get _amt => int.tryParse(_amount.text) ?? 0;
  double _cb(int a) => (a * .0142 * 100).round() / 100;

  void _pay() {
    final n = networkById(_net);
    startBillPayment(
      context,
      ref,
      BillRequest(
        kind: TxKind.airtime,
        productName: 'Airtime',
        provider: n,
        rows: [('Recipient Mobile', phoneSpaced(_phone.text)), ('Amount', money2(_amt))],
        amount: _amt,
        cashback: _cb(_amt),
        subtitle: '${n.name} · ${phoneSpaced(_phone.text)}',
        details: {'Network': n.name, 'Recipient': _phone.text},
        beneficiary: _save ? Beneficiary(id: 'b${DateTime.now().millisecondsSinceEpoch}', name: 'Saved ${n.name} number', value: _phone.text, kind: TxKind.airtime, billerId: _net) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final err = _phone.text.isNotEmpty && _phone.text.length >= 11 && !_phoneOk ? 'Enter a valid Nigerian number' : null;
    return BillScaffold(
      title: 'Airtime',
      kind: TxKind.airtime,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32),
        children: [
          const PromoStrip(title: 'Earn up to 1.4% cashback', sub: 'On every airtime top-up, instantly.', icon: PhosphorIconsDuotone.coins),
          const Gap(16),
          PhoneCard(
            controller: _phone,
            networkId: _net,
            kind: TxKind.airtime,
            error: err,
            onNetwork: (id) => setState(() => _net = id),
            onChanged: (v) {
              final d = detectNetwork(v);
              setState(() {
                if (d != null) _net = d;
              });
            },
          ),
          const Gap(12),
          SaveBeneficiaryRow(value: _save, onChanged: (v) => setState(() => _save = v)),
          const Gap(16),
          AmountCard(
            title: 'Top up',
            quick: const [100, 200, 300, 400, 500, 1000],
            controller: _amount,
            selected: _amt,
            subtitleOf: (a) => '+${money2(_cb(a))} back',
            min: 50,
            max: 500000,
            hint: '50 – 500,000',
            payEnabled: _phoneOk,
            onChanged: (_) => setState(() {}),
            onPay: _pay,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Data ─────────────────────────

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});
  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  late final _phone = TextEditingController(text: ref.read(accountProvider).phone);
  late String _net = detectNetwork(ref.read(accountProvider).phone) ?? 'mtn';
  int _tab = 0;
  bool _grid = true;
  bool _save = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _phoneOk => isNgPhone(_phone.text);

  void _select(DataPlan p) {
    if (!_phoneOk) {
      showToast(context, 'Enter a valid phone number first', error: true);
      return;
    }
    final n = networkById(_net);
    startBillPayment(
      context,
      ref,
      BillRequest(
        kind: TxKind.data,
        productName: 'Mobile Data',
        provider: n,
        rows: [('Recipient Mobile', phoneSpaced(_phone.text)), ('Data Bundle', '${p.label} ${p.validity} Plan'), ('Amount', money2(p.price))],
        amount: p.price,
        cashback: (p.price * .02 * 100).round() / 100,
        subtitle: '${n.name} · ${p.label} ${p.validity} Plan',
        details: {'Network': n.name, 'Recipient': _phone.text, 'Bundle': '${p.label} ${p.validity} Plan'},
        beneficiary: _save ? Beneficiary(id: 'b${DateTime.now().millisecondsSinceEpoch}', name: 'Saved ${n.name} number', value: _phone.text, kind: TxKind.data, billerId: _net) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = plansFor(_net, dataBuckets[_tab]);
    final err = _phone.text.length >= 11 && !_phoneOk ? 'Enter a valid Nigerian number' : null;
    return BillScaffold(
      title: 'Mobile Data',
      kind: TxKind.data,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32),
        children: [
          PhoneCard(
            controller: _phone,
            networkId: _net,
            kind: TxKind.data,
            error: err,
            onNetwork: (id) => setState(() => _net = id),
            onChanged: (v) {
              final d = detectNetwork(v);
              setState(() {
                if (d != null) _net = d;
              });
            },
          ),
          const Gap(12),
          SaveBeneficiaryRow(value: _save, onChanged: (v) => setState(() => _save = v)),
          const Gap(16),
          const PromoStrip(title: 'Top up data anytime', sub: 'Pick a plan below — delivered in seconds.', icon: PhosphorIconsDuotone.wifiHigh, gradient: C.skyGradient),
          const Gap(16),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Data Plans', style: T.h3)),
                _ViewToggle(grid: _grid, onChanged: (g) => setState(() => _grid = g)),
              ]),
              const Gap(10),
              UnderlineTabs(items: dataBuckets, index: _tab, onChanged: (i) => setState(() => _tab = i)),
              const Gap(14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _grid ? _PlanGrid(key: ValueKey('g$_tab$_net'), plans: plans, onTap: _select) : _PlanList(key: ValueKey('l$_tab$_net'), plans: plans, onTap: _select),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onChanged});
  final bool grid;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget b(bool g, PhosphorIconData i) => Pressable(
          onTap: () => onChanged(g),
          child: Container(
            width: 34,
            height: 30,
            decoration: BoxDecoration(color: grid == g ? C.tint : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Center(child: PhosphorIcon(i, size: 18, color: grid == g ? C.primary : C.faint)),
          ),
        );
    return Row(children: [b(true, PhosphorIconsFill.squaresFour), b(false, PhosphorIconsBold.listBullets)]);
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({super.key, required this.plans, required this.onTap});
  final List<DataPlan> plans;
  final ValueChanged<DataPlan> onTap;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap * 2) / 3;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final p in plans)
          SizedBox(
            width: w,
            height: 112,
            child: Pressable(
              onTap: () => onTap(p),
              scale: .96,
              child: Container(
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: p.size, style: T.moneyOf(22, w: FontWeight.w800)),
                        TextSpan(text: p.unit, style: T.moneyOf(13, w: FontWeight.w700)),
                      ])),
                      const Gap(4),
                      Text(p.validity, style: T.small.copyWith(fontSize: 12)),
                      const Gap(4),
                      Text(money(p.price), style: T.moneyOf(14, w: FontWeight.w700, color: C.primary)),
                    ]),
                  ),
                  if (p.tag != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: C.goldTint,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(p.tag!, style: T.caption.copyWith(color: C.pending, fontWeight: FontWeight.w700, fontSize: 10.5)),
                        const HGap(3),
                        const PhosphorIcon(PhosphorIconsFill.info, size: 11, color: C.pending),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
      ]);
    });
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({super.key, required this.plans, required this.onTap});
  final List<DataPlan> plans;
  final ValueChanged<DataPlan> onTap;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final p in plans)
        Pressable(
          onTap: () => onTap(p),
          scale: .99,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
            child: Row(children: [
              IconChip(PhosphorIconsDuotone.wifiHigh, size: 40, circle: true, iconSize: 20),
              const HGap(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.label, style: T.title.copyWith(fontSize: 16)),
                  const Gap(2),
                  Text(p.validity, style: T.small),
                ]),
              ),
              if (p.tag != null) ...[Tag(p.tag!, bg: C.goldTint, fg: C.pending), const HGap(10)],
              Text(money(p.price), style: T.moneyOf(15.5, w: FontWeight.w700, color: C.primary)),
            ]),
          ),
        ),
    ]);
  }
}
