// Pure input validators: dependency-free so they are easy to test.

bool isValidAccountNumber(String v) => RegExp(r'^\d{10}$').hasMatch(v);

String _norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), ' ').split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');

/// True when two names refer to the same person. Order-insensitive and
/// tolerant of a missing middle name: at least two name parts must overlap.
/// The authoritative check runs on the server against KYC data.
bool namesMatch(String a, String b) {
  final x = _norm(a).split(' ').toSet();
  final y = _norm(b).split(' ').toSet();
  if (x.isEmpty || y.isEmpty) return false;
  final shared = x.intersection(y).length;
  final needed = (x.length < y.length ? x.length : y.length) < 2 ? 1 : 2;
  return shared >= needed;
}

/// Parses a user-typed amount ("1,500") into an int, or null if invalid.
int? parseNaira(String s) {
  final d = s.replaceAll(',', '').trim();
  if (d.isEmpty || !RegExp(r'^\d+$').hasMatch(d)) return null;
  return int.tryParse(d);
}

/// Parses a decimal token amount ("12.5"), or null if invalid / non-positive.
double? parseTokens(String s) {
  final t = s.replaceAll(',', '').trim();
  if (!RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(t)) return null;
  final v = double.tryParse(t);
  return (v == null || v <= 0) ? null : v;
}

final _emailRe = RegExp(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$");
bool isEmail(String s) => s.trim().length <= 254 && _emailRe.hasMatch(s.trim());

/// Returns a short reason when the password is too weak, null when acceptable.
/// Authoritative rules are enforced by the auth backend.
String? passwordProblem(String p) {
  if (p.length < 8) return 'Use at least 8 characters';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) return 'Mix letters and numbers';
  return null;
}

/// NIN and BVN are both 11 digits.
bool isEleven(String s) => RegExp(r'^\d{11}$').hasMatch(s.trim());

/// Nigerian passport numbers look like A12345678; foreign ones vary (6–9 alphanumerics).
bool isPassportNo(String s) => RegExp(r'^[A-Za-z0-9]{6,9}$').hasMatch(s.trim());
