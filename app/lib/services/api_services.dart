import '../api/api_client.dart';
import 'contracts.dart';
import 'models.dart';

class AccountNotFound implements Exception {
  const AccountNotFound();
}

class ApiBankService implements BankService {
  ApiBankService(this._api);
  final ApiClient _api;

  @override
  Future<List<Bank>> banks() async {
    final r = await _api.get('/banks');
    return [for (final b in (r['items'] as List? ?? const [])) Bank(b['code'].toString(), (b['name'] ?? '').toString())];
  }

  @override
  Future<ResolvedAccount> resolve({required String bankCode, required String accountNumber}) async {
    try {
      final r = await _api.post('/banks/resolve', {'bankCode': bankCode, 'accountNumber': accountNumber});
      return ResolvedAccount(accountNumber: accountNumber, bank: Bank(bankCode, ''), accountName: (r['accountName'] ?? '').toString());
    } on ApiException catch (e) {
      if (e.code == 'resolve_failed' || e.status == 422) throw const AccountNotFound();
      rethrow;
    }
  }
}

class ApiFlutterwaveService implements FlutterwaveService {
  ApiFlutterwaveService(this._api);
  final ApiClient _api;

  @override
  Future<CheckoutSession> initialize({required int amount, required String idempotencyKey}) async {
    final r = await _api.post('/funding/flutterwave/initialize', {'amount': amount});
    return CheckoutSession(txRef: r['txRef'].toString(), amount: amount, checkoutUrl: r['link'].toString());
  }

  @override
  Future<PaymentOutcome> verify(String txRef) async {
    final r = await _api.get('/funding/flutterwave/${Uri.encodeComponent(txRef)}');
    return switch (r['status']) {
      'successful' => PaymentOutcome.successful,
      'failed' => PaymentOutcome.failed,
      'cancelled' => PaymentOutcome.cancelled,
      _ => PaymentOutcome.pending,
    };
  }
}

class ApiPayoutService implements PayoutService {
  ApiPayoutService(this._api);
  final ApiClient _api;

  @override
  Future<PayoutReceipt> withdrawNaira({required int amount, required PayoutAccount account, required String idempotencyKey, String? pin}) async {
    final r = await _api.post('/payouts/bank', {'amount': amount, 'accountId': account.id, 'pin': pin});
    return PayoutReceipt(reference: (r['id'] ?? '').toString(), status: (r['status'] ?? 'pending').toString());
  }
}
