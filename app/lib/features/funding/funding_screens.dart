import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/security/idempotency.dart';
import '../../core/security/secure_clipboard.dart';
import '../../core/security/validators.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/account.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../../api/api_client.dart';
import '../../api/sync.dart';
import '../../services/models.dart';
import '../../services/providers.dart';
import 'funding_widgets.dart';

// ───────────────────────── Method chooser ─────────────────────────

class AddMoneyScreen extends ConsumerWidget {
  const AddMoneyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bal = ref.watch(walletProvider).balance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Add Money'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 32), children: [
        Row(children: [
          Text('Current balance', style: T.small),
          const Spacer(),
          Text(money2(bal), style: T.title),
        ]),
        const Gap(18),
        Text('Choose a method', style: T.h3),
        const Gap(10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            _FundRow(icon: PhosphorIconsDuotone.creditCard, title: 'Debit card', sub: 'Visa, Mastercard or Verve', note: 'Instant', onTap: () => context.push('/wallet/add/naira')),
            const HairDivider(indent: 62),
            _FundRow(icon: PhosphorIconsDuotone.bank, title: 'Bank transfer', sub: 'Pay with a one-time transfer account', note: 'Instant', onTap: () => context.push('/wallet/add/naira')),
            const HairDivider(indent: 62),
            _FundRow(icon: PhosphorIconsDuotone.coins, title: '${TokenConfig.name} (${TokenConfig.symbol})', sub: 'Send CCT to your personal wallet address', note: 'Live', onTap: () => context.push('/wallet/add/cct')),
          ]),
        ),
        const Gap(18),
        const InfoBanner('Your balance updates only after our server confirms the payment. Crystal Pay never asks you to send money to a personal account.'),
      ]),
    );
  }
}

class _FundRow extends StatelessWidget {
  const _FundRow({required this.icon, required this.title, required this.sub, required this.note, required this.onTap});
  final PhosphorIconData icon;
  final String title, sub, note;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: .99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            IconChip(icon, size: 46, iconSize: 24),
            const HGap(14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.title),
                const Gap(2),
                Text(sub, style: T.small.copyWith(fontSize: 12.5)),
              ]),
            ),
            const HGap(10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(note, style: T.caption.copyWith(color: C.primary, fontWeight: FontWeight.w700)),
              const Gap(4),
              const PhosphorIcon(PhosphorIconsBold.caretRight, size: 14, color: C.faint),
            ]),
          ]),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title, this.sub);
  final int n;
  final String title, sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28, decoration: const BoxDecoration(color: C.tint, shape: BoxShape.circle), child: Center(child: Text('$n', style: T.label.copyWith(color: C.primary)))),
          const HGap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.title),
              Text(sub, style: T.small),
            ]),
          ),
        ]),
      );
}

// ───────────────────────── Naira via Flutterwave ─────────────────────────

class FundNairaScreen extends ConsumerStatefulWidget {
  const FundNairaScreen({super.key});
  @override
  ConsumerState<FundNairaScreen> createState() => _FundNairaScreenState();
}

class _FundNairaScreenState extends ConsumerState<FundNairaScreen> {
  final _c = TextEditingController();
  bool _busy = false;
  final String _key = newIdempotencyKey();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int? get _v => parseNaira(_c.text);

  String? get _err {
    final v = _v;
    if (_c.text.isEmpty) return null;
    if (v == null) return 'Enter a valid amount';
    if (v < Limits.minFundNaira) return 'Minimum is ${money(Limits.minFundNaira)}';
    if (v > Limits.maxFundNaira) return 'Maximum is ${money(Limits.maxFundNaira)} per payment';
    return null;
  }

  Future<void> _go() async {
    final v = _v!;
    setState(() => _busy = true);
    try {
      final s = await ref.read(flutterwaveServiceProvider).initialize(amount: v, idempotencyKey: _key);
      if (mounted) context.push('/wallet/add/naira/checkout', extra: s);
    } catch (_) {
      if (mounted) showToast(context, 'Could not start payment. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _v != null && _err == null;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Pay With Card'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Amount', style: T.title),
            const Gap(12),
            AmountField(controller: _c, hint: '${Limits.minFundNaira} – ${compactMoney(Limits.maxFundNaira)}', onChanged: (_) => setState(() {}), error: _err),
            const Gap(14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in const [1000, 2000, 5000, 10000, 20000, 50000])
                Pressable(
                  onTap: () => setState(() => _c.text = '$a'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(999)),
                    child: Text(money(a), style: T.label.copyWith(color: C.primary)),
                  ),
                ),
            ]),
          ]),
        ),
        const Gap(16),
        const InfoBanner('You will be taken to our payment partner’s secure page. Card details are entered there and never touch Crystal Pay.'),
        const Gap(24),
        AppButton(label: ok ? 'Continue to payment · ${money(_v!)}' : 'Continue', loading: _busy, onPressed: ok ? _go : null),
      ]),
    );
  }
}

/// Opens Flutterwave's hosted checkout in the phone's browser, then keeps asking
/// our server whether the payment landed. Only the server credits the wallet.
class GatewayCheckoutScreen extends ConsumerStatefulWidget {
  const GatewayCheckoutScreen({super.key, required this.session});
  final CheckoutSession session;
  @override
  ConsumerState<GatewayCheckoutScreen> createState() => _GatewayCheckoutState();
}

class _GatewayCheckoutState extends ConsumerState<GatewayCheckoutScreen> with WidgetsBindingObserver {
  Timer? _t;
  bool _opened = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _open() async {
    final ok = await launchUrl(Uri.parse(widget.session.checkoutUrl), mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _opened = ok);
    if (!ok && mounted) showToast(context, 'Could not open the payment page.', error: true);
  }

  Future<void> _check() async {
    if (_done || !_opened) return;
    try {
      final o = await ref.read(flutterwaveServiceProvider).verify(widget.session.txRef);
      if (o == PaymentOutcome.successful || o == PaymentOutcome.failed) _finish(false);
    } catch (_) {}
  }

  void _finish(bool cancelled) {
    if (_done || !mounted) return;
    _done = true;
    context.pushReplacement('/wallet/add/naira/result', extra: (widget.session.txRef, widget.session.amount, cancelled));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Secure Checkout', onBack: () => _finish(true)),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        AppCard(
          child: Column(children: [
            KvRow('Merchant', 'Crystal Pay'),
            KvRow('Reference', s.txRef),
            const HairDivider(),
            KvRow('Amount', money2(s.amount), bold: true),
          ]),
        ),
        const Gap(16),
        const InfoBanner('Complete your payment in the page that opened. Come back here when you are done. We confirm it automatically.'),
        const Gap(20),
        const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: C.primary))),
        const Gap(10),
        Center(child: Text('Waiting for your payment…', style: T.small)),
        const Gap(24),
        AppButton(label: 'I have paid', onPressed: () => _finish(false)),
        const Gap(10),
        AppButton(label: 'Open payment page again', kind: BtnKind.soft, onPressed: _open),
        const Gap(10),
        AppButton(label: 'Cancel', kind: BtnKind.soft, onPressed: () => _finish(true)),
      ]),
    );
  }
}

/// Never credits from the redirect. It asks the server to verify, then shows
/// the server's verdict. In production the wallet is credited by the webhook.
class FundingResultScreen extends ConsumerStatefulWidget {
  const FundingResultScreen({super.key, required this.txRef, required this.amount, required this.cancelled});
  final String txRef;
  final int amount;
  final bool cancelled;
  @override
  ConsumerState<FundingResultScreen> createState() => _FundingResultScreenState();
}

class _FundingResultScreenState extends ConsumerState<FundingResultScreen> {
  PaymentOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    if (widget.cancelled) {
      _outcome = PaymentOutcome.cancelled;
    } else {
      _verify();
    }
  }

  Future<void> _verify() async {
    setState(() => _outcome = null);
    try {
      final o = await ref.read(flutterwaveServiceProvider).verify(widget.txRef);
      if (!mounted) return;
      if (o == PaymentOutcome.successful) {
        HapticFeedback.mediumImpact();
        await ref.read(authControllerProvider).refreshAll();
      }
      if (mounted) setState(() => _outcome = o);
    } catch (_) {
      if (mounted) setState(() => _outcome = PaymentOutcome.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _outcome;
    final (icon, color, title, msg) = switch (o) {
      null => (PhosphorIconsBold.hourglass, C.primary, 'Confirming your payment', 'Checking with our server. This only takes a moment.'),
      PaymentOutcome.successful => (PhosphorIconsBold.check, C.primary, 'Wallet funded', '${money2(widget.amount)} has been added to your wallet.'),
      PaymentOutcome.failed => (PhosphorIconsBold.x, C.error, 'Payment failed', 'You were not charged. If money left your account it will be returned automatically.'),
      PaymentOutcome.cancelled => (PhosphorIconsBold.prohibit, C.muted, 'Payment cancelled', 'No money was taken from you.'),
      PaymentOutcome.pending => (PhosphorIconsBold.clock, C.pending, 'Still confirming', 'We have not received confirmation yet. Your wallet will update automatically once we do.'),
    };
    final loading = o == null;
    return PopScope(
      canPop: !loading,
      child: Scaffold(
        backgroundColor: C.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sp.page),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                child: Center(child: loading ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3.4, color: C.primary)) : PhosphorIcon(icon, size: 48, color: color)),
              ),
              const Gap(26),
              Text(title, style: T.h1),
              const Gap(8),
              Text(msg, style: T.small.copyWith(fontSize: 14), textAlign: TextAlign.center),
              if (o == PaymentOutcome.successful) ...[
                const Gap(22),
                AppCard(color: C.bg, borderColor: null, child: Column(children: [KvRow('Reference', widget.txRef), KvRow('Amount', money2(widget.amount), bold: true)])),
              ],
              const Spacer(),
              if (o == PaymentOutcome.pending) ...[
                AppButton(label: 'Check again', onPressed: _verify),
                const Gap(10),
              ],
              if (o == PaymentOutcome.failed || o == PaymentOutcome.cancelled) ...[
                AppButton(label: 'Try again', onPressed: () => context.go('/wallet/add/naira')),
                const Gap(10),
              ],
              if (!loading) AppButton(label: 'Done', kind: o == PaymentOutcome.successful ? BtnKind.primary : BtnKind.soft, onPressed: () {
                context.go('/home');
                context.push('/wallet');
              }),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Fund with CCT (personal wallet address) ─────────────────────────

class _CctInfo {
  _CctInfo(this.address, this.rate, this.fee, this.network, this.confirmations, this.watching, this.testMode);
  final String address, network;
  final double rate, fee;
  final int confirmations;
  final bool watching, testMode;
}

class _CctDep {
  _CctDep(this.id, this.tokens, this.status, this.confirmations, this.required, this.net, this.at, this.simulated);
  final String id, status;
  final double tokens;
  final int confirmations, required;
  final double? net;
  final DateTime? at;
  final bool simulated;
}

class CctFundScreen extends ConsumerStatefulWidget {
  const CctFundScreen({super.key});
  @override
  ConsumerState<CctFundScreen> createState() => _CctFundScreenState();
}

class _CctFundScreenState extends ConsumerState<CctFundScreen> {
  _CctInfo? _info;
  List<_CctDep> _deps = const [];
  String? _error;
  Timer? _t;
  bool _sim = false;
  final _seenDone = <String>{};
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get('/cct/address');
      if (!mounted) return;
      setState(() {
        _info = _CctInfo(r['address'].toString(), (r['rate'] as num).toDouble(), (r['feePercent'] as num).toDouble(), (r['network'] ?? '').toString(), (r['confirmations'] as num).toInt(), r['watching'] == true, r['testMode'] == true);
        _error = null;
      });
      await _poll();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException && e.isNetwork ? 'No internet connection.' : 'Could not load your wallet address.');
    }
  }

  Future<void> _poll() async {
    if (_info == null) return;
    try {
      final r = await ref.read(apiProvider).get('/cct/deposits');
      final list = [
        for (final d in (r['items'] as List? ?? const []))
          _CctDep(d['id'].toString(), (d['tokens'] as num).toDouble(), d['status'].toString(), (d['confirmations'] as num?)?.toInt() ?? 0, (d['required'] as num?)?.toInt() ?? 12, (d['netNaira'] as num?)?.toDouble(), DateTime.tryParse('${d['detectedAt']}')?.toLocal(), d['simulated'] == true),
      ];
      if (!mounted) return;
      var credited = false;
      for (final d in list) {
        if (d.status == 'completed' && _seenDone.add(d.id) && !_first) credited = true;
      }
      _first = false;
      setState(() => _deps = list);
      if (credited) {
        HapticFeedback.mediumImpact();
        await ref.read(authControllerProvider).refreshAll();
      }
    } catch (_) {}
  }

  Future<void> _simulate() async {
    setState(() => _sim = true);
    try {
      await ref.read(apiProvider).post('/cct/simulate', {'tokens': 100});
      await _poll();
      if (mounted) showToast(context, 'Test deposit of 100 CCT sent. It confirms in under a minute.');
    } catch (e) {
      if (mounted) showToast(context, e is ApiException ? e.message : 'Could not start the test deposit.', error: true);
    } finally {
      if (mounted) setState(() => _sim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Your CCT Wallet'),
      body: i == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : EmptyState(icon: PhosphorIconsDuotone.warningCircle, title: 'Something went wrong', message: _error!, actionLabel: 'Try again', onAction: _load))
          : ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 40), children: [
              AppCard(
                child: Column(children: [
                  Text('Send CCT to this address', style: T.small),
                  const Gap(14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                    child: QrImageView(data: i.address, size: 150, padding: EdgeInsets.zero, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.navy), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: C.navy)),
                  ),
                  const Gap(14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(i.address, textAlign: TextAlign.center, style: T.bodyM.copyWith(fontSize: 13, height: 1.4)),
                  ),
                  const Gap(10),
                  AppButton(label: 'Copy address', small: true, kind: BtnKind.soft, icon: PhosphorIconsRegular.copy, onPressed: () async {
                    await copySensitive(i.address);
                    if (context.mounted) showToast(context, 'Address copied');
                  }),
                  const Gap(12),
                  KvRow('Network', i.network),
                  KvRow('Rate', '1 CCT = ${money2(i.rate)}'),
                  KvRow('Fee', '${i.fee}%'),
                  KvRow('Confirmations', '${i.confirmations}'),
                ]),
              ),
              const Gap(12),
              InfoBanner('Send only ${TokenConfig.symbol} on ${i.network}. Anything else sent to this address cannot be recovered. This address is yours, and you can reuse it.', kind: BannerKind.error),
              if (!i.watching) ...[
                const Gap(10),
                const InfoBanner('Live CCT detection is being switched on. Deposits made before then are picked up once it is on.', kind: BannerKind.warning),
              ],
              if (i.testMode) ...[
                const Gap(12),
                AppButton(label: 'Send a test deposit (100 CCT)', kind: BtnKind.soft, loading: _sim, onPressed: _simulate),
              ],
              const Gap(18),
              Row(children: [
                Text('Deposits', style: T.h3),
                const Spacer(),
                Row(children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle)),
                  const HGap(6),
                  Text('Live', style: T.caption),
                ]),
              ]),
              const Gap(10),
              if (_deps.isEmpty)
                AppCard(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('Waiting for your first deposit. It shows up here the moment it is on the network.', textAlign: TextAlign.center, style: T.small))))
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [for (var k = 0; k < _deps.length; k++) _DepRow(d: _deps[k], last: k == _deps.length - 1)]),
                ),
            ]),
    );
  }
}

class _DepRow extends StatelessWidget {
  const _DepRow({required this.d, required this.last});
  final _CctDep d;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final done = d.status == 'completed';
    final failed = d.status == 'failed';
    final label = done ? 'Credited' : failed ? 'Failed' : d.status == 'confirming' ? 'Confirming ${d.confirmations}/${d.required}' : 'Detected';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.border))),
      child: Row(children: [
        IconChip(done ? PhosphorIconsBold.check : failed ? PhosphorIconsBold.x : PhosphorIconsBold.hourglass, size: 36, iconSize: 17),
        const HGap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tokens(d.tokens)} ${TokenConfig.symbol}${d.simulated ? ' · test' : ''}', style: T.title),
            Text(label, style: T.small.copyWith(color: done ? C.primary : failed ? C.error : C.muted)),
          ]),
        ),
        if (d.net != null) Text('+${money2(d.net!)}', style: T.moneyOf(14, w: FontWeight.w700, color: C.primary)),
      ]),
    );
  }
}
