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
import '../../data/catalog.dart';
import '../../data/models.dart';
import 'bill_common.dart';

class InternationalListScreen extends StatefulWidget {
  const InternationalListScreen({super.key});
  @override
  State<InternationalListScreen> createState() => _InternationalListScreenState();
}

class _InternationalListScreenState extends State<InternationalListScreen> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final list = intlOperators.where((o) => q.isEmpty || o.name.toLowerCase().contains(q) || o.code.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: C.surface,
      appBar: AppTopBar(title: 'International Airtime', actionLabel: 'History', onAction: () => context.push('/transactions?kind=international')),
      body: Column(children: [
        Container(
          color: C.bg,
          padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 12),
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            cursorColor: C.primary,
            style: T.bodyM,
            decoration: InputDecoration(
              hintText: 'Search country or operator',
              prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 10), child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: C.muted)),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.primary, width: 1.4)),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: PhosphorIconsDuotone.globeHemisphereWest, title: 'No operators found', message: 'Try a different country or operator name.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final o = list[i];
                    return Pressable(
                      onTap: () => context.push('/bills/international/${o.code}'),
                      scale: .99,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(border: i == list.length - 1 ? null : const Border(bottom: BorderSide(color: C.border))),
                        child: Row(children: [
                          ProviderLogo(asset: o.flag, name: o.name, size: 46),
                          const HGap(14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.name, style: T.title.copyWith(fontSize: 15.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const Gap(2),
                              Text(o.code, style: T.caption.copyWith(color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                            ]),
                          ),
                          const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class InternationalPayScreen extends ConsumerStatefulWidget {
  const InternationalPayScreen({super.key, required this.code});
  final String code;
  @override
  ConsumerState<InternationalPayScreen> createState() => _InternationalPayScreenState();
}

class _InternationalPayScreenState extends ConsumerState<InternationalPayScreen> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  late final IntlOperator _op = intlOperators.firstWhere((o) => o.code == widget.code, orElse: () => intlOperators.first);

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _amt => int.tryParse(_amount.text) ?? 0;

  void _pay() {
    startBillPayment(
      context,
      ref,
      BillRequest(
        kind: TxKind.international,
        productName: 'International Airtime',
        rows: [('Operator', _op.name), ('Recipient', '${_op.dial} ${_phone.text}'), ('Amount', money2(_amt))],
        amount: _amt,
        subtitle: '${_op.name} · ${_op.dial} ${_phone.text}',
        details: {'Operator': _op.name, 'Recipient': '${_op.dial} ${_phone.text}'},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BillScaffold(
      title: _op.name,
      kind: TxKind.international,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ProviderLogo(asset: _op.flag, name: _op.name, size: 46),
                const HGap(12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_op.name, style: T.title.copyWith(fontSize: 16)),
                    Text('Operator code · ${_op.code}', style: T.small),
                  ]),
                ),
              ]),
              const Gap(16),
              Text('Recipient number', style: T.label),
              const Gap(8),
              Row(children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: C.bg, borderRadius: R.inputR),
                  alignment: Alignment.center,
                  child: Text(_op.dial, style: T.moneyOf(17, w: FontWeight.w700)),
                ),
                const HGap(10),
                Expanded(
                  child: AppTextField(
                    controller: _phone,
                    keyboard: TextInputType.phone,
                    hint: 'Phone number',
                    fill: C.bg,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    onChanged: (_) => setState(() {}),
                    textStyle: T.moneyOf(18, w: FontWeight.w700),
                  ),
                ),
              ]),
            ]),
          ),
          const Gap(14),
          AmountCard(
            title: 'Select Amount',
            quick: const [1000, 2000, 5000, 10000, 20000, 50000],
            controller: _amount,
            selected: _amt,
            min: 500,
            max: 100000,
            hint: '500 – 100,000',
            payEnabled: _phone.text.length >= 7,
            onChanged: (_) => setState(() {}),
            onPay: _pay,
          ),
          const Gap(12),
          const InfoBanner('Rates are indicative and may vary at the time of delivery. Airtime is delivered in minutes.'),
        ],
      ),
    );
  }
}
