import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/common.dart' show Status;
import 'catalog.dart';
import 'mock_data.dart';
import 'account.dart';
import 'models.dart';

// ───────────────────────── Session (UI-only) ─────────────────────────

class SessionState {
  const SessionState({this.seenOnboarding = false, this.loggedIn = false});
  final bool seenOnboarding;
  final bool loggedIn;
  SessionState copyWith({bool? seenOnboarding, bool? loggedIn}) =>
      SessionState(seenOnboarding: seenOnboarding ?? this.seenOnboarding, loggedIn: loggedIn ?? this.loggedIn);
}

/// Front-end only: there is no authentication. Signing in simply flips a flag.
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();
  void finishOnboarding() => state = state.copyWith(seenOnboarding: true);
  void signIn() => state = state.copyWith(loggedIn: true, seenOnboarding: true);
  void signOut() => state = state.copyWith(loggedIn: false);
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

// ───────────────────────── Wallet ─────────────────────────

class InsufficientFunds implements Exception {
  InsufficientFunds(this.balance, this.needed);
  final num balance;
  final num needed;
}

class WalletState {
  const WalletState({required this.balance, required this.txs, this.cashback = 1842.5});
  final num balance;
  final List<Tx> txs;
  final num cashback;
  WalletState copyWith({num? balance, List<Tx>? txs, num? cashback}) => WalletState(balance: balance ?? this.balance, txs: txs ?? this.txs, cashback: cashback ?? this.cashback);
}

class WalletNotifier extends Notifier<WalletState> {
  int _n = 100;

  @override
  WalletState build() => WalletState(balance: 48750, txs: List.of(mockTxs));

  String _id() => 'tx${_n++}';

  /// Debits the wallet and records a successful transaction.
  /// Throws [InsufficientFunds] when the balance is too low.
  Tx pay({
    required TxKind kind,
    required String title,
    required String subtitle,
    required num amount,
    Map<String, String> details = const {},
    String? token,
    Status status = Status.success,
  }) {
    if (amount > state.balance) throw InsufficientFunds(state.balance, amount);
    final tx = Tx(id: _id(), kind: kind, title: title, subtitle: subtitle, amount: amount, credit: false, status: status, date: DateTime.now(), details: details, token: token);
    state = state.copyWith(balance: state.balance - amount, txs: [tx, ...state.txs]);
    return tx;
  }

  Tx topUp(num amount, String method, {TxKind kind = TxKind.topup, Map<String, String> details = const {}}) {
    final tx = Tx(id: _id(), kind: kind, title: kind.label == 'Add Money' ? 'Add Money' : kind.label, subtitle: method, amount: amount, credit: true, status: Status.success, date: DateTime.now(), details: {'Method': method, ...details});
    state = state.copyWith(balance: state.balance + amount, txs: [tx, ...state.txs]);
    return tx;
  }

  /// Debits [amount] plus [fee]. The recorded amount is the total debited.
  Tx withdraw(num amount, String bank, {num fee = 0, Map<String, String> details = const {}}) {
    final total = amount + fee;
    if (total > state.balance) throw InsufficientFunds(state.balance, total);
    final tx = Tx(id: _id(), kind: TxKind.withdraw, title: 'Withdrawal', subtitle: 'To $bank', amount: total, credit: false, status: Status.success, date: DateTime.now(), details: {'Bank': bank, ...details});
    state = state.copyWith(balance: state.balance - total, txs: [tx, ...state.txs]);
    return tx;
  }

  /// Records a transaction that settled outside the wallet (e.g. CCT paid
  /// straight to a bank account). The wallet balance is unchanged.
  Tx recordExternal({required TxKind kind, required String title, required String subtitle, required num amount, Map<String, String> details = const {}}) {
    final tx = Tx(id: _id(), kind: kind, title: title, subtitle: subtitle, amount: amount, credit: false, status: Status.success, date: DateTime.now(), details: details);
    state = state.copyWith(txs: [tx, ...state.txs]);
    return tx;
  }

  void addCashback(num v) => state = state.copyWith(cashback: state.cashback + v);

  Tx? find(String id) {
    for (final t in state.txs) {
      if (t.id == id) return t;
    }
    return null;
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);

class BalanceHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final balanceHiddenProvider = NotifierProvider<BalanceHiddenNotifier, bool>(BalanceHiddenNotifier.new);

// ───────────────────────── Marketplace ─────────────────────────

class ListingsNotifier extends Notifier<List<Listing>> {
  @override
  List<Listing> build() => [...myMockListings, ...mockListings];

  void add(Listing l) => state = [l, ...state];
  void update(Listing l) => state = [for (final x in state) x.id == l.id ? l : x];
  void remove(String id) => state = state.where((l) => l.id != id).toList();
  void boost(String id) => state = [for (final x in state) x.id == id ? x.copyWith(boostedUntil: DateTime.now().add(const Duration(days: 7))) : x];
  void setStatus(String id, ListingStatus s) => state = [for (final x in state) x.id == id ? x.copyWith(status: s) : x];
}

final listingsProvider = NotifierProvider<ListingsNotifier, List<Listing>>(ListingsNotifier.new);

/// Everything visible in the public feed (active listings).
final feedProvider = Provider<List<Listing>>((ref) {
  // A lapsed seller plan hides that seller's items until they renew.
  final planOk = ref.watch(accountProvider).planActive;
  final all = ref.watch(listingsProvider).where((l) => l.status == ListingStatus.active && (planOk || l.seller.id != 'me')).toList();
  all.sort((a, b) => b.postedAt.compareTo(a.postedAt));
  return all;
});

final myListingsProvider = Provider<List<Listing>>((ref) {
  return ref.watch(listingsProvider).where((l) => l.seller.id == 'me').toList();
});

final listingByIdProvider = Provider.family<Listing?, String>((ref, id) {
  for (final l in ref.watch(listingsProvider)) {
    if (l.id == id) return l;
  }
  return null;
});

class SavedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'l6', 'l3', 'l1'};
  bool toggle(String id) {
    final next = {...state};
    final added = next.add(id);
    if (!added) next.remove(id);
    state = next;
    return added;
  }
}

final savedProvider = NotifierProvider<SavedNotifier, Set<String>>(SavedNotifier.new);

// ───────────────────────── Cart ─────────────────────────

/// Marketplace cart (listing ids). Property is never added: it cannot be
/// paid for in the app.
class CartNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  /// Returns false when the item is already in the cart.
  bool add(String id) {
    if (state.contains(id)) return false;
    state = [...state, id];
    return true;
  }

  void remove(String id) => state = state.where((x) => x != id).toList();
  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartNotifier, List<String>>(CartNotifier.new);

/// Cart items that can still be bought (active, not property).
final cartItemsProvider = Provider<List<Listing>>((ref) {
  final ids = ref.watch(cartProvider);
  final all = ref.watch(listingsProvider);
  return [
    for (final id in ids)
      for (final l in all)
        if (l.id == id && l.status == ListingStatus.active && !l.isRealEstate) l,
  ];
});

class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['iPhone', 'Smart TV', 'Standing fan', 'Camera'];
  void add(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    state = [t, ...state.where((e) => e.toLowerCase() != t.toLowerCase())].take(8).toList();
  }

  void clear() => state = [];
}

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);

// ───────────────────────── Orders ─────────────────────────

class OrdersNotifier extends Notifier<List<Order>> {
  int _n = 48400;
  @override
  List<Order> build() => List.of(mockOrders);

  Order place(Listing l, {required String method, required String address, required int deliveryFee, required int total}) {
    final o = Order(id: 'CP-${_n++}', listing: l, role: OrderRole.buying, stage: OrderStage.paid, total: total, deliveryFee: deliveryFee, date: DateTime.now(), counterparty: l.seller.name, method: method, address: address);
    state = [o, ...state];
    return o;
  }

  void setStage(String id, OrderStage s) => state = [for (final o in state) o.id == id ? o.copyWith(stage: s) : o];
  void markReviewed(String id) => state = [for (final o in state) o.id == id ? o.copyWith(reviewed: true) : o];
  Order? find(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

// ───────────────────────── Chats ─────────────────────────

class ChatsNotifier extends Notifier<List<ChatThread>> {
  int _n = 10;
  @override
  List<ChatThread> build() => List.of(mockChats);

  /// Returns the id of an existing thread for [l], or creates one.
  String open(Listing l) {
    for (final c in state) {
      if (c.listing.id == l.id) return c.id;
    }
    final t = ChatThread(id: 'c${_n++}', seller: l.seller, listing: l, messages: const []);
    state = [t, ...state];
    return t.id;
  }

  void send(String id, String text, {int? offer}) {
    final msg = Msg(text: text, mine: true, time: DateTime.now(), offer: offer);
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(messages: [...c.messages, msg], unread: 0) else c
    ];
  }

  void reply(String id, String text) {
    final msg = Msg(text: text, mine: false, time: DateTime.now());
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(messages: [...c.messages, msg]) else c
    ];
  }

  void markRead(String id) => state = [for (final c in state) c.id == id ? c.copyWith(unread: 0) : c];
}

final chatsProvider = NotifierProvider<ChatsNotifier, List<ChatThread>>(ChatsNotifier.new);

final unreadChatsProvider = Provider<int>((ref) => ref.watch(chatsProvider).fold(0, (a, c) => a + c.unread));

// ───────────────────────── Notifications & beneficiaries ─────────────────────────

class NotesNotifier extends Notifier<List<AppNote>> {
  @override
  List<AppNote> build() => List.of(mockNotes);
  void add(AppNote n) => state = [n, ...state];
  void markAllRead() => state = [for (final n in state) n.copyWith(read: true)];
  void markRead(String id) => state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
}

final notesProvider = NotifierProvider<NotesNotifier, List<AppNote>>(NotesNotifier.new);
final unreadNotesProvider = Provider<int>((ref) => ref.watch(notesProvider).where((n) => !n.read).length);

class BeneficiariesNotifier extends Notifier<List<Beneficiary>> {
  @override
  List<Beneficiary> build() => List.of(mockBeneficiaries);
  void add(Beneficiary b) {
    if (state.any((x) => x.value == b.value && x.kind == b.kind)) return;
    state = [b, ...state];
  }

  void remove(String id) => state = state.where((b) => b.id != id).toList();
}

final beneficiariesProvider = NotifierProvider<BeneficiariesNotifier, List<Beneficiary>>(BeneficiariesNotifier.new);

// ───────────────────────── Preferences ─────────────────────────

class PrefsState {
  const PrefsState({this.biometric = true, this.pushOrders = true, this.pushPromos = false, this.pushBills = true, this.hideBalanceOnOpen = false});
  final bool biometric, pushOrders, pushPromos, pushBills, hideBalanceOnOpen;
  PrefsState copyWith({bool? biometric, bool? pushOrders, bool? pushPromos, bool? pushBills, bool? hideBalanceOnOpen}) => PrefsState(
        biometric: biometric ?? this.biometric,
        pushOrders: pushOrders ?? this.pushOrders,
        pushPromos: pushPromos ?? this.pushPromos,
        pushBills: pushBills ?? this.pushBills,
        hideBalanceOnOpen: hideBalanceOnOpen ?? this.hideBalanceOnOpen,
      );
}

class PrefsNotifier extends Notifier<PrefsState> {
  @override
  PrefsState build() => const PrefsState();
  void set(PrefsState s) => state = s;
}

final prefsProvider = NotifierProvider<PrefsNotifier, PrefsState>(PrefsNotifier.new);

// ───────────────────────── Helpers ─────────────────────────

/// Deterministic mock customer-name lookup for meters / smartcards / IDs.
String mockCustomerName(String number) {
  const names = ['ADAEZE C. NWOKE', 'NNAMDI F. OKEKE', 'IBRAHIM M. SANI', 'FUNMILAYO A. BELLO', 'CHUKWUDI E. OKAFOR', 'BLESSING T. UDOH', 'AISHA B. YUSUF', 'EMEKA J. IGWE'];
  final sum = number.codeUnits.fold<int>(0, (a, b) => a + b);
  if (number == '45031987266') return 'NNAMDI F. OKEKE';
  return names[sum % names.length];
}

/// Networks detected from a Nigerian phone prefix.
String? detectNetwork(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length < 4) return null;
  final p = d.substring(0, 4);
  const mtn = ['0803', '0806', '0703', '0706', '0813', '0816', '0810', '0814', '0903', '0906', '0913', '0916', '0704'];
  const airtel = ['0802', '0808', '0708', '0812', '0701', '0902', '0901', '0904', '0907', '0912'];
  const glo = ['0805', '0807', '0705', '0815', '0811', '0905', '0915'];
  const t2 = ['0809', '0818', '0817', '0909', '0908'];
  if (mtn.contains(p)) return 'mtn';
  if (airtel.contains(p)) return 'airtel';
  if (glo.contains(p)) return 'glo';
  if (t2.contains(p)) return 't2';
  return null;
}

/// Shorthand used by UI for catalogue lookups.
Biller? billerFor(String? id) {
  if (id == null) return null;
  for (final list in [networks, discos, tvProviders, bettingProviders, internetProviders]) {
    for (final b in list) {
      if (b.id == id) return b;
    }
  }
  return null;
}
