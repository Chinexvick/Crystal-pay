import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_pay/core/utils/format.dart';
import 'package:crystal_pay/data/mock_data.dart';
import 'package:crystal_pay/data/models.dart';
import 'package:crystal_pay/data/state.dart';
import 'package:crystal_pay/features/market/market_screen.dart';
import 'package:crystal_pay/core/security/validators.dart';
import 'package:crystal_pay/core/security/pin_guard.dart';
import 'package:crystal_pay/core/security/idempotency.dart';
import 'package:crystal_pay/services/mock_services.dart';
import 'package:crystal_pay/data/account.dart';
import 'package:crystal_pay/data/plans.dart';
import 'package:crystal_pay/data/catalog.dart';
import 'package:crystal_pay/features/sell/insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:crystal_pay/features/wallet/send_money.dart';

void main() {
  test('wallet debits and rejects overdraft', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final w = c.read(walletProvider.notifier);
    final before = c.read(walletProvider).balance;
    w.pay(kind: TxKind.airtime, title: 'Airtime', subtitle: 'MTN', amount: 1000);
    expect(c.read(walletProvider).balance, before - 1000);
    expect(() => w.pay(kind: TxKind.data, title: 'x', subtitle: 'y', amount: 99999999), throwsA(isA<InsufficientFunds>()));
  });

  test('order placement is recorded as buying', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final l = mockListings.first;
    final o = c.read(ordersProvider.notifier).place(l, method: 'Pickup', address: 'x', deliveryFee: 0, total: l.price);
    expect(c.read(ordersProvider).first.id, o.id);
    expect(o.role, OrderRole.buying);
  });

  test('listing filter by price and sort', () {
    const f = ListingFilter(max: 50000, sort: SortBy.priceLow);
    final r = f.apply(mockListings);
    expect(r.every((l) => l.price <= 50000), isTrue);
    for (var i = 1; i < r.length; i++) {
      expect(r[i].price >= r[i - 1].price, isTrue);
    }
  });

  test('network detection and phone validation', () {
    expect(detectNetwork('08031234567'), 'mtn');
    expect(detectNetwork('08021234567'), 'airtel');
    expect(isNgPhone('08030000001'), isTrue);
    expect(isNgPhone('12345'), isFalse);
  });

  test('money formatting uses naira', () {
    expect(money(185000), '₦185,000');
    expect(money2(1842.5), '₦1,842.50');
  });

  group('payout security', () {
    test('account number must be exactly 10 digits', () {
      expect(isValidAccountNumber('0123456789'), isTrue);
      expect(isValidAccountNumber('012345678'), isFalse);
      expect(isValidAccountNumber('01234567890'), isFalse);
      expect(isValidAccountNumber('01234abcde'), isFalse);
    });

    test('account name must match the verified name', () {
      expect(namesMatch('VICTORY BASSEY', 'Victory Bassey'), isTrue);
      expect(namesMatch('BASSEY VICTORY OKAFOR', 'Victory Bassey'), isTrue);
      expect(namesMatch('ADEBAYO OLUWASEUN TUNDE', 'Victory Bassey'), isFalse);
      expect(namesMatch('VICTORY ADEBAYO', 'Victory Bassey'), isFalse);
    });

    test('amount parsing rejects junk', () {
      expect(parseNaira('1,500'), 1500);
      expect(parseNaira('12abc'), isNull);
      expect(parseNaira('-5'), isNull);
      expect(parseTokens('12.5'), 12.5);
      expect(parseTokens('0'), isNull);
      expect(parseTokens('1.1234567'), isNull);
    });

    test('PIN locks after 3 failures', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final g = c.read(pinGuardProvider.notifier);
      g.fail();
      g.fail();
      expect(c.read(pinGuardProvider).locked, isFalse);
      g.fail();
      expect(c.read(pinGuardProvider).locked, isTrue);
      g.success();
      expect(c.read(pinGuardProvider).locked, isFalse);
    });

    test('idempotency keys are unique and 32 hex chars', () {
      final a = newIdempotencyKey(), b = newIdempotencyKey();
      expect(a, isNot(b));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a), isTrue);
    });
  });

  group('CCT quotes', () {
    test('fund quote covers the requested Naira plus fee', () async {
      final q = await MockTokenService().quoteFund(10000);
      expect(q.netNaira, 10000);
      expect(q.tokens * q.rate, greaterThanOrEqualTo(10000));
    });
  });

  group('Seller plans and real estate', () {
    test('Basic is 3000 naira for 5 listings and tiers rise', () {
      expect(planById(PlanId.basic).price, 3000);
      expect(planById(PlanId.basic).listingLimit, 5);
      expect(planById(PlanId.pro).listingLimit, greaterThan(5));
      expect(planById(PlanId.business).listingLimit, greaterThan(planById(PlanId.pro).listingLimit));
    });

    test('boosts are limited by the plan and reset on subscribe', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final a = c.read(accountProvider.notifier);
      a.subscribe(PlanId.pro);
      expect(c.read(accountProvider).boostsLeft, 3);
      a.useBoost();
      expect(c.read(accountProvider).boostsLeft, 2);
      a.subscribe(PlanId.pro);
      expect(c.read(accountProvider).boostsLeft, 3);
      a.subscribe(PlanId.basic);
      expect(c.read(accountProvider).boostsLeft, 0);
    });

    test('boosting a listing marks it featured for a week', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final mine = c.read(myListingsProvider).first;
      expect(mine.isBoosted, isFalse);
      c.read(listingsProvider.notifier).boost(mine.id);
      final after = c.read(listingByIdProvider(mine.id))!;
      expect(after.isBoosted, isTrue);
      expect(after.boostedUntil!.difference(DateTime.now()).inDays, greaterThanOrEqualTo(6));
    });

    test('houses and lands are property: flagged, contactable, never in the cart', () {
      final re = mockListings.where((l) => l.isRealEstate).toList();
      expect(re, isNotEmpty);
      expect(re.every((l) => l.contactPhone != null), isTrue);
      expect(categories.any((c) => c.id == 'houses'), isTrue);
      expect(categories.any((c) => c.id == 'lands'), isTrue);
      expect(re.any((l) => l.isLand), isTrue);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(cartProvider.notifier).add(re.first.id);
      expect(c.read(cartItemsProvider), isEmpty);
    });

    test('cart adds once, resolves items and clears', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(cartProvider.notifier);
      expect(n.add('l1'), isTrue);
      expect(n.add('l1'), isFalse);
      n.add('l3');
      expect(c.read(cartItemsProvider).map((l) => l.id), containsAll(['l1', 'l3']));
      n.remove('l1');
      expect(c.read(cartProvider), ['l3']);
      n.clear();
      expect(c.read(cartProvider), isEmpty);
    });

    test('send money finds users by username, phone or email, and checks usernames', () {
      expect(findPayUser('@chijioke')?.name, 'Chijioke Obi');
      expect(findPayUser('0803 111 2233')?.username, 'chijioke');
      expect(findPayUser('amaka@crystalpay.app')?.username, 'amaka');
      expect(findPayUser('@nobody'), isNull);
      expect(isValidUsername('victory'), isTrue);
      expect(isValidUsername('ab'), isFalse);
      expect(isValidUsername('bad name'), isFalse);
    });

    test('a lapsed plan hides the seller items from the feed', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(feedProvider).any((l) => l.seller.id == 'me'), isTrue);
      c.read(accountProvider.notifier).state = c.read(accountProvider).copyWith(planRenews: DateTime.now().subtract(const Duration(days: 1)));
      expect(c.read(feedProvider).any((l) => l.seller.id == 'me'), isFalse);
    });

    testWidgets('insights screen renders for Pro', (t) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(accountProvider.notifier).subscribe(PlanId.pro);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: InsightsScreen())));
      await t.pump();
      expect(find.text('By listing'), findsOneWidget);
      expect(noErrors(t), isTrue);
    });
  });
}

bool noErrors(WidgetTester t) => t.takeException() == null;
