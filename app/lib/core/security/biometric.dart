import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper over the platform fingerprint / face prompt.
/// Biometrics only unlock the app on this device; the server never sees them.
/// Every call fails closed: on any error or unsupported platform the answer is
/// "not available" / "not authenticated" and the PIN remains the fallback.
class Biometrics {
  Biometrics._();
  static final _auth = LocalAuthentication();

  static Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}
