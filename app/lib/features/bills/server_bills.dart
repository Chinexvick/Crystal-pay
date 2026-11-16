import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/sync.dart';

class BillItem {
  const BillItem({required this.code, required this.name, required this.amount, required this.label});
  final String code;
  final String name;
  final num amount;
  final String label;
}

/// What the payment partner sells for one provider: plans, bouquets, meter types.
final billItemsProvider = FutureProvider.autoDispose.family<List<BillItem>, (String, String)>((ref, key) async {
  final r = await ref.read(apiProvider).get('/bills/plans', query: {'kind': key.$1, 'provider': key.$2});
  return [
    for (final x in (r['items'] as List? ?? const []))
      BillItem(code: x['itemCode'].toString(), name: (x['name'] ?? '').toString(), amount: (x['amount'] as num?) ?? 0, label: (x['label'] ?? 'Customer ID').toString()),
  ];
});

/// Providers the payment partner supports, per service.
final billSupportProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final r = await ref.read(apiProvider).get('/bills/providers');
  final s = Map<String, dynamic>.from(r['supported'] as Map);
  return {for (final e in s.entries) e.key: List<String>.from(e.value as List)};
});

/// Returns the customer's name, or throws [ApiException] when the number is not found.
Future<String?> validateCustomer(WidgetRef ref, {required String kind, required String provider, required String itemCode, required String customer}) async {
  final r = await ref.read(apiProvider).post('/bills/validate', {'kind': kind, 'provider': provider, 'itemCode': itemCode, 'customer': customer});
  return r['name'] as String?;
}

String apiKindOf(String txKind) => switch (txKind) { 'electricity' => 'power', _ => txKind };

/// Picks prepaid / postpaid item for electricity, falling back to the first.
BillItem? pickPower(List<BillItem> items, {required bool prepaid}) {
  if (items.isEmpty) return null;
  final want = prepaid ? 'PREPAID' : 'POSTPAID';
  for (final i in items) {
    if (i.name.toUpperCase().contains(want)) return i;
  }
  return items.first;
}

// ignore: unused_element
void _unused(ApiException e) {}
