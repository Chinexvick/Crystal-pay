import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/common.dart' show Status;
import '../data/account.dart';
import '../data/models.dart';
import '../data/state.dart';
import 'api_client.dart';

final apiProvider = Provider<ApiClient>((ref) {
  final c = ApiClient();
  c.onSessionExpired = () => ref.read(authControllerProvider).signOutLocal();
  return c;
});

final authControllerProvider = Provider<AuthController>((ref) => AuthController(ref));

TxKind _kind(String k) => switch (k) {
      'fund_card' => TxKind.topup,
      'fund_cct' => TxKind.cctTopup,
      'withdraw' => TxKind.withdraw,
      'bill_airtime' => TxKind.airtime,
      'bill_data' => TxKind.data,
      'bill_power' => TxKind.electricity,
      'bill_tv' => TxKind.tv,
      'bill_internet' => TxKind.internet,
      'refund' => TxKind.refund,
      _ => TxKind.transfer,
    };

NoteKind _noteKind(String k) => switch (k) {
      'wallet' => NoteKind.wallet,
      'payment' => NoteKind.bill,
      'security' => NoteKind.security,
      _ => NoteKind.promo,
    };

String _pretty(String k) => switch (k) {
      'customer' => 'Recipient',
      'provider' => 'Provider',
      'itemCode' => 'Plan code',
      'bank' => 'Bank',
      'account' => 'Account',
      'accountName' => 'Account name',
      'fee' => 'Fee',
      'rate' => 'Rate (₦ per CCT)',
      'tokens' => 'CCT sent',
      'txHash' => 'Transaction',
      'method' => 'Method',
      'txRef' => 'Reference',
      _ => k,
    };

Tx txFromJson(Json j) {
  final d = (j['details'] is Map) ? Map<String, dynamic>.from(j['details'] as Map) : <String, dynamic>{};
  final details = <String, String>{
    for (final e in d.entries)
      if (!const {'simulated', 'originalRef', 'feeKobo', 'flwId', 'token'}.contains(e.key) && e.value != null && '${e.value}'.isNotEmpty) _pretty(e.key): '${e.value}',
    'Reference': (j['reference'] ?? '').toString(),
    if (d['simulated'] == true) 'Mode': 'Test (sandbox)',
  };
  final credit = j['type'] == 'credit';
  final title = (j['title'] ?? '').toString();
  return Tx(
    id: (j['id'] ?? '').toString(),
    kind: _kind((j['kind'] ?? '').toString()),
    title: title.split(' · ').first,
    subtitle: title.contains(' · ') ? title.split(' · ').skip(1).join(' · ') : (d['customer']?.toString() ?? ''),
    amount: (j['amount'] as num?) ?? 0,
    credit: credit,
    status: switch (j['status']) { 'success' => Status.success, 'failed' => Status.failed, _ => Status.pending },
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal() ?? DateTime.now(),
    details: details,
    token: d['token']?.toString(),
  );
}

/// Sign-in state, session restore, and refreshing everything from the server.
class AuthController {
  AuthController(this.ref);
  final Ref ref;
  Timer? _poll;

  ApiClient get api => ref.read(apiProvider);

  /// Restores a saved session on app start. Returns true when signed in.
  Future<bool> bootstrap() async {
    await api.load();
    if (!api.hasSession) return false;
    try {
      final me = await api.get('/me');
      ref.read(accountProvider.notifier).applyServer(me);
      ref.read(sessionProvider.notifier).signIn();
      unawaited(refreshAll());
      _startPolling();
      return true;
    } on ApiException catch (e) {
      if (e.isNetwork) {
        ref.read(sessionProvider.notifier).signIn(); // offline: let them in, data refreshes later
        _startPolling();
        return true;
      }
      return false;
    }
  }

  Future<void> signedIn(Json auth) async {
    await api.setTokens(auth['accessToken'] as String, auth['refreshToken'] as String);
    ref.read(accountProvider.notifier).applyServer(Map<String, dynamic>.from(auth['user'] as Map));
    ref.read(sessionProvider.notifier).signIn();
    unawaited(refreshAll());
    _startPolling();
  }

  void signOutLocal() {
    _poll?.cancel();
    ref.read(sessionProvider.notifier).signOut();
    ref.read(accountProvider.notifier).clear();
    ref.read(walletProvider.notifier).reset();
    ref.read(notesProvider.notifier).replace(const []);
  }

  Future<void> signOut() async {
    await api.clear();
    signOutLocal();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 25), (_) => refreshAll());
  }

  Future<void> refreshProfile() async {
    try {
      ref.read(accountProvider.notifier).applyServer(await api.get('/me'));
    } catch (_) {}
  }

  Future<void> refreshWallet() async {
    try {
      final w = await api.get('/wallet');
      final t = await api.get('/transactions', query: {'limit': '60'});
      final txs = [for (final x in (t['items'] as List? ?? const [])) txFromJson(Map<String, dynamic>.from(x as Map))];
      ref.read(walletProvider.notifier).applyServer((w['balance'] as num?) ?? 0, txs);
    } catch (_) {}
  }

  Future<void> refreshNotes() async {
    try {
      final n = await api.get('/notifications');
      final list = [
        for (final x in (n['items'] as List? ?? const []))
          AppNote(
            id: (x['id']).toString(),
            kind: _noteKind((x['kind'] ?? '').toString()),
            title: (x['title'] ?? '').toString(),
            body: (x['body'] ?? '').toString(),
            time: DateTime.tryParse((x['date'] ?? '').toString())?.toLocal() ?? DateTime.now(),
            read: x['read'] == true,
          ),
      ];
      ref.read(notesProvider.notifier).replace(list);
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshWallet(), refreshNotes()]);
  }

  Future<void> markNotesRead() async {
    ref.read(notesProvider.notifier).markAllRead();
    try {
      await api.post('/notifications/read');
    } catch (_) {}
  }
}
