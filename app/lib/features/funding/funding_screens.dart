import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
            _FundRow(icon: PhosphorIconsDuotone.bank, title: 'Bank transfer', sub: 'Send from any bank app to your wallet account', note: 'Instant', onTap: () => context.push('/wallet/add/transfer')),
            const HairDivider(indent: 62),
            _FundRow(icon: PhosphorIconsDuotone.coins, title: '${TokenConfig.name} (${TokenConfig.symbol})', sub: 'Send from your crypto wallet, we convert to Naira', note: '~1 min', onTap: () => context.push('/wallet/add/cct')),
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

/// Pay by bank transfer into the user's dedicated wallet account.
class FundTransferScreen extends ConsumerWidget {
  const FundTransferScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acct = ref.watch(accountProvider);
    const number = '9000012345';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Bank Transfer'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 32), children: [
        Text('Transfer to this account from any bank app. Your wallet is credited automatically.', style: T.small.copyWith(fontSize: 14)),
        const Gap(16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const BankLogo(code: '035', name: 'Wema Bank', size: 44),
              const HGap(12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Wema Bank', style: T.title),
                Text('Your Crystal Pay account', style: T.small),
              ]),
            ]),
            const Gap(18),
            Text('Account number', style: T.small),
            const Gap(4),
            Row(children: [
              Text('9051 482 770', style: T.moneyOf(28)),
              const Spacer(),
              Pressable(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: number));
                  showToast(context, 'Account number copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const PhosphorIcon(PhosphorIconsRegular.copy, size: 15, color: C.primary),
                    const HGap(6),
                    Text('Copy', style: T.label.copyWith(color: C.primary)),
                  ]),
                ),
              ),
            ]),
            const Gap(14),
            const HairDivider(),
            KvRow('Account name', acct.fullName.toUpperCase()),
          ]),
        ),
        const Gap(18),
        Text('How it works', style: T.h3),
        const Gap(10),
        const _Step(1, 'Open your bank app', 'Choose transfer to another bank.'),
        const _Step(2, 'Send to the account above', 'Any amount from ₦100 up, from any Nigerian bank.'),
        const _Step(3, 'Wait about a minute', 'We credit your wallet as soon as the bank confirms.'),
        const Gap(8),
        const InfoBanner('Only send Naira to this account. Transfers from other currencies are not credited.', kind: BannerKind.warning),
      ]),
    );
  }
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

/// Stand-in for the gateway's hosted checkout.
/// Production: open `session.checkoutUrl` in an in-app browser tab, never in a
/// WebView that can read the page, then return here with the tx_ref.
class GatewayCheckoutScreen extends StatelessWidget {
  const GatewayCheckoutScreen({super.key, required this.session});
  final CheckoutSession session;

  @override
  Widget build(BuildContext context) {
    void finish(bool cancelled) => context.pushReplacement('/wallet/add/naira/result', extra: (session.txRef, session.amount, cancelled));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Secure Checkout', onBack: () => finish(true)),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        const InfoBanner('Demo page. In the live app this is the payment partner’s hosted checkout opened in a secure browser tab.', kind: BannerKind.warning),
        const Gap(16),
        AppCard(
          child: Column(children: [
            KvRow('Merchant', 'Crystal Pay'),
            KvRow('Reference', session.txRef),
            const HairDivider(),
            KvRow('Amount', money2(session.amount), bold: true),
          ]),
        ),
        const Gap(16),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: const [
            _PayOpt(PhosphorIconsDuotone.creditCard, 'Pay with card', 'Visa, Mastercard, Verve'),
            HairDivider(indent: 54),
            _PayOpt(PhosphorIconsDuotone.bank, 'Pay with bank transfer', 'Transfer to a one-time account'),
            HairDivider(indent: 54),
            _PayOpt(PhosphorIconsDuotone.hash, 'Pay with USSD', 'Dial a short code on your phone'),
          ]),
        ),
        const Gap(24),
        AppButton(label: 'Pay ${money(session.amount)}', onPressed: () => finish(false)),
        const Gap(10),
        AppButton(label: 'Cancel payment', kind: BtnKind.soft, onPressed: () => finish(true)),
      ]),
    );
  }
}

class _PayOpt extends StatelessWidget {
  const _PayOpt(this.icon, this.title, this.sub);
  final PhosphorIconData icon;
  final String title, sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          IconChip(icon, size: 40, iconSize: 21),
          const HGap(14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: T.title), Text(sub, style: T.small.copyWith(fontSize: 12))])),
        ]),
      );
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
  Tx? _tx;

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
      if (o == PaymentOutcome.successful && _tx == null) {
        _tx = ref.read(walletProvider.notifier).topUp(widget.amount, 'Card / Bank (Flutterwave)', details: {'Reference': widget.txRef});
        HapticFeedback.mediumImpact();
      }
      setState(() => _outcome = o);
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

// ───────────────────────── Fund with CCT ─────────────────────────

class CctFundScreen extends ConsumerStatefulWidget {
  const CctFundScreen({super.key});
  @override
  ConsumerState<CctFundScreen> createState() => _CctFundScreenState();
}

class _CctFundScreenState extends ConsumerState<CctFundScreen> {
  final _c = TextEditingController();
  Quote? _quote;
  bool _busy = false;
  bool _ack = false;

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
    if (v > Limits.maxFundNaira) return 'Maximum is ${money(Limits.maxFundNaira)}';
    return null;
  }

  Future<void> _quoteIt() async {
    setState(() {
      _busy = true;
      _quote = null;
      _ack = false;
    });
    try {
      final q = await ref.read(tokenServiceProvider).quoteFund(_v!);
      if (mounted) setState(() => _quote = q);
    } catch (_) {
      if (mounted) showToast(context, 'Could not get a rate. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final s = await ref.read(tokenServiceProvider).openDeposit(quote: _quote!, idempotencyKey: newIdempotencyKey());
      if (mounted) context.pushReplacement('/wallet/cct/deposit/${s.id}');
    } catch (_) {
      if (mounted) showToast(context, 'Could not create a deposit address. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final validQuote = q != null && !q.expired;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const AppTopBar(title: 'Fund With CCT'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 32), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How much Naira do you want in your wallet?', style: T.title),
            const Gap(12),
            AmountField(controller: _c, hint: 'Amount in Naira', onChanged: (_) => setState(() => _quote = null), error: _err),
            const Gap(14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in const [5000, 10000, 25000, 50000, 100000])
                Pressable(
                  onTap: () => setState(() {
                    _c.text = '$a';
                    _quote = null;
                  }),
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
        if (q == null)
          AppButton(label: 'Get rate', loading: _busy, onPressed: _v != null && _err == null ? _quoteIt : null)
        else ...[
          QuoteSummary(quote: q, onExpired: () => setState(() {})),
          const Gap(14),
          if (q.expired)
            Column(children: [
              const InfoBanner('This rate has expired.', kind: BannerKind.warning),
              const Gap(12),
              AppButton(label: 'Get a new rate', loading: _busy, onPressed: _quoteIt),
            ])
          else ...[
            Pressable(
              onTap: () => setState(() => _ack = !_ack),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(color: _ack ? C.primary : C.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: _ack ? C.primary : C.border, width: 1.6)),
                  child: _ack ? const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 14, color: Colors.white)) : null,
                ),
                const HGap(10),
                Expanded(child: Text('I will send exactly ${tokens(q.tokens)} ${TokenConfig.symbol} on ${TokenConfig.network}. Other tokens or networks cannot be recovered.', style: T.small.copyWith(fontSize: 13))),
              ]),
            ),
            const Gap(18),
            AppButton(label: 'Show deposit address', icon: PhosphorIconsBold.qrCode, loading: _busy, onPressed: validQuote && _ack ? _open : null),
          ],
        ],
      ]),
    );
  }
}

// ───────────────────────── Deposit (fund wallet with CCT) ─────────────────────────

class DepositScreen extends ConsumerWidget {
  const DepositScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(depositProvider(id));
    return async.when(
      loading: () => const Scaffold(backgroundColor: C.bg, body: Center(child: CircularProgressIndicator(color: C.primary))),
      error: (_, _) => const Scaffold(backgroundColor: C.bg, body: EmptyState(icon: PhosphorIconsDuotone.warningCircle, title: 'Something went wrong', message: 'We could not load this deposit.')),
      data: (s) => _DepositView(s: s),
    );
  }
}

class _DepositView extends StatelessWidget {
  const _DepositView({required this.s});
  final DepositSession s;

  @override
  Widget build(BuildContext context) {
    final q = s.quote;
    final done = s.status == DepositStatus.completed;
    final awaiting = s.status == DepositStatus.awaiting;
    final expired = s.status == DepositStatus.expired;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppTopBar(title: 'Send CCT', onBack: () {
        context.go('/home');
        context.push('/wallet');
      }),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 40), children: [
        if (done)
          _Done(s: s)
        else if (expired)
          const InfoBanner('This request expired before we received your transfer. Start again to get a new rate and address.', kind: BannerKind.error)
        else ...[
          AppCard(
            child: Column(children: [
              Text('Send exactly', style: T.small),
              const Gap(4),
              Text('${tokens(q.tokens)} ${TokenConfig.symbol}', style: T.moneyOf(32, color: C.primary)),
              const Gap(2),
              Text('You will receive ${money2(q.netNaira)} in your wallet', style: T.small),
              const Gap(18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.border)),
                child: QrImageView(data: s.address, size: 178, padding: EdgeInsets.zero, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.navy), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: C.navy)),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Deposit address', style: T.caption),
                  const Gap(4),
                  SelectableText(s.address, style: T.bodyM.copyWith(fontFeatures: const [FontFeature.tabularFigures()], height: 1.4)),
                ]),
              ),
              const Gap(12),
              Row(children: [
                Expanded(
                  child: AppButton(label: 'Address', small: true, kind: BtnKind.soft, icon: PhosphorIconsRegular.copy, onPressed: () async {
                    await copySensitive(s.address);
                    if (context.mounted) showToast(context, 'Address copied. Clipboard clears in 60s');
                  }),
                ),
                const HGap(10),
                Expanded(
                  child: AppButton(label: 'Amount', small: true, kind: BtnKind.soft, icon: PhosphorIconsRegular.copy, onPressed: () {
                    Clipboard.setData(ClipboardData(text: q.tokens.toString()));
                    showToast(context, 'Amount copied');
                  }),
                ),
              ]),
              const Gap(14),
              KvRow('Network', TokenConfig.network),
              if (awaiting) KvRow('Address valid for', '${q.remaining.inMinutes} min'),
            ]),
          ),
          const Gap(14),
          InfoBanner('Send only ${TokenConfig.symbol} on ${TokenConfig.network}. Any other token or network will be lost permanently. Send the exact amount, because a different amount may be delayed or refused.', kind: BannerKind.error),
          const Gap(14),
          DepositStepper(session: s),
          const Gap(14),
          const InfoBanner('You can leave this screen. We will notify you when it completes.\nDemo mode: the transfer is simulated automatically.', kind: BannerKind.info),
        ],
        if (expired) ...[
          const Gap(16),
          AppButton(label: 'Start again', onPressed: () => context.go('/wallet/add/cct')),
        ],
      ]),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.s});
  final DepositSession s;
  @override
  Widget build(BuildContext context) {
    final q = s.quote;
    return Column(children: [
      const Gap(24),
      Container(
        width: 104,
        height: 104,
        decoration: const BoxDecoration(gradient: C.brandGradient, shape: BoxShape.circle),
        child: const Center(child: PhosphorIcon(PhosphorIconsBold.check, size: 52, color: Colors.white)),
      ),
      const Gap(22),
      Text('Wallet funded', style: T.h1),
      const Gap(8),
      Text('${money2(q.netNaira)} was added to your wallet.', textAlign: TextAlign.center, style: T.small.copyWith(fontSize: 14)),
      const Gap(22),
      AppCard(
        child: Column(children: [
          KvRow('Sent', '${tokens(q.tokens)} ${TokenConfig.symbol}'),
          KvRow('Rate', '1 CCT = ${money2(q.rate)}'),
          KvRow('Fee', money2(q.feeNaira)),
          const HairDivider(),
          KvRow('Credited', money2(q.netNaira), bold: true),
          if (s.reference != null) KvRow('Reference', s.reference!),
        ]),
      ),
      const Gap(24),
      AppButton(label: 'Done', onPressed: () {
                context.go('/home');
                context.push('/wallet');
              }),
      const Gap(10),
      AppButton(label: 'View transactions', kind: BtnKind.soft, onPressed: () => context.go('/transactions')),
    ]);
  }
}
