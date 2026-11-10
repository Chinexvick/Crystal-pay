import 'models.dart';

/// Every method here maps 1:1 to a backend endpoint. The UI only talks to
/// these interfaces. Swapping the mock for the real client changes no screen.

abstract class BankService {
  /// GET /banks, list of supported Nigerian banks.
  Future<List<Bank>> banks();

  /// POST /banks/resolve, name enquiry for an account number.
  Future<ResolvedAccount> resolve({required String bankCode, required String accountNumber});
}

abstract class FlutterwaveService {
  /// POST /funding/flutterwave/initialize, server creates the tx_ref and
  /// returns the hosted checkout link. The amount is re-validated server side.
  Future<CheckoutSession> initialize({required int amount, required String idempotencyKey});

  /// GET /funding/flutterwave/:txRef, server verifies with Flutterwave.
  /// The wallet is credited by the webhook, never by this call or the redirect.
  Future<PaymentOutcome> verify(String txRef);
}

abstract class TokenService {
  /// GET /cct/rate, indicative Naira per 1 CCT (the locked rate comes from a quote).
  Future<double> indicativeRate();

  /// POST /cct/quotes/fund, user wants [nairaAmount] in their wallet.
  Future<Quote> quoteFund(int nairaAmount);

  /// POST /cct/deposits, issues a unique deposit address bound to the quote.
  Future<DepositSession> openDeposit({required Quote quote, required String idempotencyKey});

  /// GET /cct/deposits/:id (or a websocket). Emits every status change.
  Stream<DepositSession> watch(String id);

  /// Every session update, for app-wide side effects (credit, notify).
  Stream<DepositSession> get updates;

  DepositSession? current(String id);
}

abstract class PayoutService {
  /// POST /payouts/bank, withdraw Naira from the wallet to a verified account.
  Future<PayoutReceipt> withdrawNaira({required int amount, required PayoutAccount account, required String idempotencyKey});
}
