import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'tx_widgets.dart';

class BeneficiariesScreen extends ConsumerStatefulWidget {
  const BeneficiariesScreen({super.key});
  @override
  ConsumerState<BeneficiariesScreen> createState() => _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends ConsumerState<BeneficiariesScreen> {
  int _f = 0;
  static const _filters = <(String, TxKind?)>[('All', null), ('Airtime', TxKind.airtime), ('Electricity', TxKind.electricity), ('TV', TxKind.tv), ('Betting', TxKind.betting)];

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(beneficiariesProvider);
    final k = _filters[_f].$2;
    final list = all.where((b) => k == null || b.kind == k).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Beneficiaries', actions: [RoundIconButton(icon: PhosphorIconsBold.plus, onTap: () => _add(context), size: 40)]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: ChipRow(items: [for (final f in _filters) f.$1], index: _f, onChanged: (i) => setState(() => _f = i))),
        Expanded(
          child: list.isEmpty
              ? EmptyState(icon: PhosphorIconsDuotone.addressBook, title: 'No beneficiaries yet', message: 'Save phone numbers, meters and smartcards for one-tap payments.', actionLabel: 'Add beneficiary', onAction: () => _add(context))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Gap(10),
                  itemBuilder: (_, i) {
                    final b = list[i];
                    return Dismissible(
                      key: ValueKey(b.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: BoxDecoration(color: C.errorTint, borderRadius: BorderRadius.circular(R.card)),
                        child: const PhosphorIcon(PhosphorIconsFill.trash, color: C.error, size: 22),
                      ),
                      onDismissed: (_) {
                        ref.read(beneficiariesProvider.notifier).remove(b.id);
                        showToast(context, '${b.name} removed');
                      },
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          IconChip(txIcon(b.kind), size: 44, iconSize: 22),
                          const HGap(12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(b.name, style: T.title),
                              const Gap(2),
                              Text(b.kind == TxKind.airtime ? phoneSpaced(b.value) : b.value, style: T.small),
                            ]),
                          ),
                          Pressable(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: b.value));
                              showToast(context, 'Copied');
                            },
                            child: const Padding(padding: EdgeInsets.all(8), child: PhosphorIcon(PhosphorIconsRegular.copy, size: 18, color: C.muted)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _add(BuildContext context) {
    final name = TextEditingController();
    final value = TextEditingController();
    var kind = TxKind.airtime;
    showAppSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SheetFrame(
          title: 'Add beneficiary',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Type', style: T.label),
            const Gap(8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in const [TxKind.airtime, TxKind.electricity, TxKind.tv, TxKind.betting])
                Pressable(
                  onTap: () => set(() => kind = k),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: kind == k ? C.primary : C.bg, borderRadius: BorderRadius.circular(999)),
                    child: Text(k.label, style: T.label.copyWith(color: kind == k ? Colors.white : C.muted)),
                  ),
                ),
            ]),
            const Gap(16),
            AppTextField(controller: name, label: 'Nickname', hint: 'e.g. Mum', fill: C.bg),
            const Gap(14),
            AppTextField(controller: value, label: switch (kind) { TxKind.airtime => 'Phone number', TxKind.electricity => 'Meter number', TxKind.tv => 'Smartcard number', _ => 'User ID' }, hint: 'Enter number', keyboard: TextInputType.number, fill: C.bg, formatters: [FilteringTextInputFormatter.digitsOnly]),
            const Gap(20),
            AppButton(
              label: 'Save',
              onPressed: () {
                if (name.text.trim().isEmpty || value.text.trim().length < 6) {
                  showToast(ctx, 'Enter a nickname and a valid number', error: true);
                  return;
                }
                ref.read(beneficiariesProvider.notifier).add(Beneficiary(id: 'b${DateTime.now().millisecondsSinceEpoch}', name: name.text.trim(), value: value.text.trim(), kind: kind));
                Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      ),
    );
  }
}
