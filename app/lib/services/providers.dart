
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/state.dart';
import 'contracts.dart';
import 'mock_services.dart';
import 'models.dart';

// Swap these for real implementations when the backend is ready, or override
// them in tests. No screen constructs a service directly.
final bankServiceProvider = Provider<BankService>((ref) => MockBankService());
final flutterwaveServiceProvider = Provider<FlutterwaveService>((ref) => MockFlutterwaveService());
final tokenServiceProvider = Provider<TokenService>((ref) => MockTokenService());
final payoutServiceProvider = Provider<PayoutService>((ref) => MockPayoutService());

final cctRateProvider = FutureProvider<double>((ref) => ref.watch(tokenServiceProvider).indicativeRate());

final banksProvider = FutureProvider<List<Bank>>((ref) => ref.watch(bankServiceProvider).banks());

final depositProvider = StreamProvider.family<DepositSession, String>((ref, id) => ref.watch(tokenServiceProvider).watch(id));

/// Verified payout accounts. In production this is GET /payout-accounts.
class PayoutAccountsNotifier extends Notifier<List<PayoutAccount>> {
  @override
  List<PayoutAccount> build() => const [
        PayoutAccount(id: 'pa1', bank: Bank('058', 'Guaranty Trust Bank'), accountNumber: '0123456781', accountName: 'VICTORY BASSEY'),
      ];

  void add(PayoutAccount a) {
    if (state.any((x) => x.accountNumber == a.accountNumber && x.bank.code == a.bank.code)) return;
    state = [...state, a];
  }

  void remove(String id) => state = state.where((a) => a.id != id).toList();
}

final payoutAccountsProvider = NotifierProvider<PayoutAccountsNotifier, List<PayoutAccount>>(PayoutAccountsNotifier.new);

/// Total already withdrawn today, for the daily cap.
final sentOutTodayProvider = Provider<num>((ref) {
  final now = DateTime.now();
  return ref.watch(walletProvider).txs.where((t) => t.kind == TxKind.withdraw && t.date.year == now.year && t.date.month == now.month && t.date.day == now.day).fold<num>(0, (a, t) => a + t.amount);
});

/// App-wide listener that applies the result of finished CCT deposits exactly
/// once (credit wallet / notify) even if the user left the
/// deposit screen. In production the backend credits the ledger and this only
/// refreshes the balance.
final depositFinalizerProvider = Provider<void>((ref) {
  final applied = <String>{};
  final sub = ref.watch(tokenServiceProvider).updates.listen((s) {
    if (s.status != DepositStatus.completed || !applied.add(s.id)) return;
    final wallet = ref.read(walletProvider.notifier);
    final notes = ref.read(notesProvider.notifier);
    final q = s.quote;
      wallet.topUp(q.netNaira, 'Crystal Cat (CCT)', kind: TxKind.cctTopup, details: {'Sent': '${q.tokens} CCT', 'Rate': '₦${q.rate} / CCT', 'Reference': s.reference ?? ''});
      notes.add(AppNote(id: 'n_${s.id}', kind: NoteKind.wallet, title: 'Wallet credited', body: '₦${q.netNaira.toStringAsFixed(0)} was added from your CCT deposit.', time: DateTime.now()));
  });
  ref.onDispose(sub.cancel);
});
