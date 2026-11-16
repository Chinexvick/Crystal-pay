import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/sync.dart';
import '../data/models.dart';
import '../data/state.dart';
import 'api_services.dart';
import 'contracts.dart';
import 'models.dart';

final bankServiceProvider = Provider<BankService>((ref) => ApiBankService(ref.read(apiProvider)));
final flutterwaveServiceProvider = Provider<FlutterwaveService>((ref) => ApiFlutterwaveService(ref.read(apiProvider)));
final payoutServiceProvider = Provider<PayoutService>((ref) => ApiPayoutService(ref.read(apiProvider)));

final banksProvider = FutureProvider<List<Bank>>((ref) => ref.watch(bankServiceProvider).banks());

/// The user's saved bank accounts, kept on the server.
class PayoutAccountsNotifier extends Notifier<List<PayoutAccount>> {
  @override
  List<PayoutAccount> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    try {
      final r = await ref.read(apiProvider).get('/payout-accounts');
      state = [for (final a in (r['items'] as List? ?? const [])) _from(a)];
    } catch (_) {/* keep what we have */}
  }

  PayoutAccount _from(dynamic a) => PayoutAccount(id: a['id'].toString(), bank: Bank(a['bankCode'].toString(), (a['bankName'] ?? '').toString()), accountNumber: a['accountNumber'].toString(), accountName: (a['accountName'] ?? '').toString());

  Future<PayoutAccount> create(Bank bank, String number, String name) async {
    final r = await ref.read(apiProvider).post('/payout-accounts', {'bankCode': bank.code, 'bankName': bank.name, 'accountNumber': number, 'accountName': name});
    final acct = _from(r);
    state = [acct, ...state.where((x) => x.id != acct.id)];
    return acct;
  }

  Future<void> remove(String id) async {
    await ref.read(apiProvider).delete('/payout-accounts/$id');
    state = state.where((a) => a.id != id).toList();
  }

  void clear() => state = const [];
}

final payoutAccountsProvider = NotifierProvider<PayoutAccountsNotifier, List<PayoutAccount>>(PayoutAccountsNotifier.new);

/// Total already withdrawn today, for the daily cap.
final sentOutTodayProvider = Provider<num>((ref) {
  final now = DateTime.now();
  return ref.watch(walletProvider).txs.where((t) => t.kind == TxKind.withdraw && t.date.year == now.year && t.date.month == now.month && t.date.day == now.day).fold<num>(0, (a, t) => a + t.amount);
});
