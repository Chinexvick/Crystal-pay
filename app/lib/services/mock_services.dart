import 'dart:async';
import 'dart:math';

import '../core/config/app_config.dart';
import '../core/security/idempotency.dart';
import 'contracts.dart';
import 'models.dart';

const mockRateNairaPerCct = 12.40;

const _bankList = <Bank>[
  Bank('044', 'Access Bank'),
  Bank('063', 'Access Bank (Diamond)'),
  Bank('035A', 'ALAT by WEMA'),
  Bank('023', 'Citibank Nigeria'),
  Bank('050', 'Ecobank Nigeria'),
  Bank('562', 'Ekondo Microfinance Bank'),
  Bank('070', 'Fidelity Bank'),
  Bank('011', 'First Bank of Nigeria'),
  Bank('214', 'First City Monument Bank'),
  Bank('058', 'Guaranty Trust Bank'),
  Bank('030', 'Heritage Bank'),
  Bank('301', 'Jaiz Bank'),
  Bank('082', 'Keystone Bank'),
  Bank('50211', 'Kuda Microfinance Bank'),
  Bank('50515', 'Moniepoint MFB'),
  Bank('999992', 'OPay'),
  Bank('999991', 'PalmPay'),
  Bank('076', 'Polaris Bank'),
  Bank('101', 'Providus Bank'),
  Bank('221', 'Stanbic IBTC Bank'),
  Bank('068', 'Standard Chartered Bank'),
  Bank('232', 'Sterling Bank'),
  Bank('100', 'Suntrust Bank'),
  Bank('032', 'Union Bank of Nigeria'),
  Bank('033', 'United Bank for Africa'),
  Bank('215', 'Unity Bank'),
  Bank('035', 'Wema Bank'),
  Bank('057', 'Zenith Bank'),
];

class MockBankService implements BankService {
  @override
  Future<List<Bank>> banks() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _bankList;
  }

  /// Demo rule: account numbers ending in 0 resolve to someone else's name,
  /// everything else resolves to the signed-in user's legal name.
  @override
  Future<ResolvedAccount> resolve({required String bankCode, required String accountNumber}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final bank = _bankList.firstWhere((b) => b.code == bankCode, orElse: () => _bankList.first);
    if (accountNumber.endsWith('9')) throw const AccountNotFound();
    final name = accountNumber.endsWith('0') ? 'ADEBAYO OLUWASEUN TUNDE' : 'VICTORY BASSEY';
    return ResolvedAccount(accountNumber: accountNumber, bank: bank, accountName: name);
  }
}

class AccountNotFound implements Exception {
  const AccountNotFound();
}

class MockFlutterwaveService implements FlutterwaveService {
  @override
  Future<CheckoutSession> initialize({required int amount, required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return CheckoutSession(txRef: 'CP-FW-${DateTime.now().millisecondsSinceEpoch}', amount: amount, checkoutUrl: 'https://checkout.flutterwave.com/v3/hosted/pay/demo');
  }

  @override
  Future<PaymentOutcome> verify(String txRef) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    return PaymentOutcome.successful;
  }
}

class MockPayoutService implements PayoutService {
  @override
  Future<PayoutReceipt> withdrawNaira({required int amount, required PayoutAccount account, required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return PayoutReceipt(reference: 'PO-${idempotencyKey.substring(0, 8).toUpperCase()}', status: 'queued');
  }
}

/// Simulates the blockchain watcher: detection → confirmations → conversion
/// Timings are compressed for demos.
class MockTokenService implements TokenService {
  final _sessions = <String, DepositSession>{};
  final _all = StreamController<DepositSession>.broadcast();
  final _per = <String, StreamController<DepositSession>>{};
  final _rng = Random.secure();

  @override
  Future<double> indicativeRate() async => mockRateNairaPerCct;

  @override
  Stream<DepositSession> get updates => _all.stream;

  @override
  DepositSession? current(String id) => _sessions[id];

  @override
  Future<Quote> quoteFund(int nairaAmount) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final fee = nairaAmount * Fees.cctServicePercent / 100;
    final tokens = (nairaAmount + fee) / mockRateNairaPerCct;
    return Quote(
      id: 'q_${newIdempotencyKey().substring(0, 10)}',
      rate: mockRateNairaPerCct,
      tokens: _round(tokens),
      grossNaira: nairaAmount + fee,
      feeNaira: fee,
      netNaira: nairaAmount.toDouble(),
      expiresAt: DateTime.now().add(TokenConfig.quoteTtl),
    );
  }

  double _round(double v) => (v * 10000).ceil() / 10000;

  String _address() {
    const hex = '0123456789abcdef';
    return '0x${List.generate(40, (_) => hex[_rng.nextInt(16)]).join()}';
  }

  @override
  Future<DepositSession> openDeposit({required Quote quote, required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final s = DepositSession(id: 'dep_${idempotencyKey.substring(0, 12)}', quote: quote, address: _address(), status: DepositStatus.awaiting);
    _sessions[s.id] = s;
    _per[s.id] = StreamController<DepositSession>.broadcast();
    unawaited(_simulate(s.id));
    return s;
  }

  @override
  Stream<DepositSession> watch(String id) async* {
    final cur = _sessions[id];
    if (cur != null) yield cur;
    final c = _per[id];
    if (c != null) yield* c.stream;
  }

  void _emit(DepositSession s) {
    _sessions[s.id] = s;
    _per[s.id]?.add(s);
    _all.add(s);
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _simulate(String id) async {
    await _wait(9000); // "user sends tokens"
    var s = _sessions[id]!;
    if (s.status.terminal) return;
    _emit(s = s.copyWith(status: DepositStatus.detected));
    await _wait(1400);
    for (var c = 1; c <= s.required; c++) {
      await _wait(320);
      _emit(s = s.copyWith(status: DepositStatus.confirming, confirmations: c));
    }
    await _wait(900);
    _emit(s = s.copyWith(status: DepositStatus.converting));
    await _wait(1500);
    _emit(s.copyWith(status: DepositStatus.completed, reference: 'CCT-${id.substring(4, 12).toUpperCase()}'));
  }
}
