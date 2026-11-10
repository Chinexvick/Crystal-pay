import 'package:intl/intl.dart';

const naira = '₦';

final _money0 = NumberFormat('#,##0', 'en_US');
final _money2 = NumberFormat('#,##0.00', 'en_US');

/// ₦1,000 or ₦1,000.50
String money(num v, {bool decimals = false}) {
  if (decimals || v % 1 != 0) return '$naira${_money2.format(v)}';
  return '$naira${_money0.format(v)}';
}

/// Always two decimals: ₦1,000.00
String money2(num v) => '$naira${_money2.format(v)}';

String signedMoney(num v, {required bool credit}) => '${credit ? '+' : '-'}${money2(v)}';

String compactMoney(num v) {
  if (v >= 1000000) return '$naira${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
  if (v >= 100000) return '$naira${(v / 1000).toStringAsFixed(0)}K';
  return money(v);
}

String ordinal(int d) {
  if (d >= 11 && d <= 13) return '${d}th';
  switch (d % 10) {
    case 1:
      return '${d}st';
    case 2:
      return '${d}nd';
    case 3:
      return '${d}rd';
    default:
      return '${d}th';
  }
}

/// "Sep 27th, 23:12"
String txDate(DateTime d) => '${DateFormat('MMM').format(d)} ${ordinal(d.day)}, ${DateFormat('HH:mm').format(d)}';

String longDate(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

String monthYear(DateTime d) => DateFormat('MMM yyyy').format(d);

String timeAgo(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return DateFormat('d MMM').format(d);
}

String clock(DateTime d) => DateFormat('h:mm a').format(d);

/// 08030000001 → 0803 000 0001
String phoneSpaced(String s) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return s;
  return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
}

String maskAccount(String s) => s.length < 6 ? s : '${s.substring(0, 3)}••••${s.substring(s.length - 3)}';

String initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  if (p.isEmpty || p.first.isEmpty) return '?';
  if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
  return (p.first[0] + p.last[0]).toUpperCase();
}

/// Nigerian mobile number: 11 digits starting with 0.
bool isNgPhone(String s) => RegExp(r'^0[789][01]\d{8}$').hasMatch(s.replaceAll(RegExp(r'\s'), ''));
