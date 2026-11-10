/// Single place for business rules the backend will own in production.
/// Values here are display/validation hints only. The server must enforce
/// every limit, fee and rate again, because a client can never be trusted.
class TokenConfig {
  TokenConfig._();
  static const symbol = 'CCT';
  static const name = 'Crystal Cat';

  /// TODO(backend): confirm the chain CCT lives on. The warning text, address
  /// format and QR payload all derive from this.
  static const network = 'BNB Smart Chain (BEP-20)';

  /// Confirmations the watcher waits for before converting.
  static const confirmationsRequired = 12;

  /// How long a locked quote stays valid.
  static const quoteTtl = Duration(minutes: 15);

}

class Limits {
  Limits._();
  static const minFundNaira = 100;
  static const maxFundNaira = 5000000;
  static const minWithdrawNaira = 100;
  static const maxWithdrawNaira = 2000000;

  /// Per-day outbound cap for the current verification tier (Tier 2).
  static const dailyOutNaira = 2000000;
}

class Fees {
  Fees._();

  /// Flat fee for a Naira withdrawal to a bank.
  static const withdrawNaira = 50;

  /// Service fee on CCT conversions (percent of the Naira value).
  static const cctServicePercent = 1.5;
}

class Security {
  Security._();

  /// Lock the app after being in the background this long.
  static const autoLockAfter = Duration(seconds: 45);
  static const pinMaxAttempts = 3;
  static const pinLockout = Duration(seconds: 30);

  /// Clipboard is wiped this long after copying a deposit address.
  static const clipboardClearAfter = Duration(seconds: 60);
}
