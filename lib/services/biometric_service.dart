import 'package:local_auth/local_auth.dart';

abstract final class BiometricService {
  static final _auth = LocalAuthentication();

  /// Returns true if the device has biometrics enrolled or supports device
  /// credentials (PIN / pattern / password) as a fallback.
  static Future<bool> isAvailable() async {
    final canCheck   = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck || isSupported;
  }

  /// Prompts the user to authenticate. Falls back to device PIN/pattern if
  /// biometrics are not enrolled. Returns true on success.
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock PariTsa',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
