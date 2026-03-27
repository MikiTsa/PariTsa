import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Provides permission check and settings navigation for the Android
/// [WalletNotificationService]. All methods no-op on non-Android platforms.
///
/// The actual expense capture (Firestore write + notification) runs entirely
/// inside the Kotlin service, so this class is only needed for the
/// Settings screen UI.
class WalletNotificationService {
  static const _methodChannel = MethodChannel(
    'com.example.expenses_tracker/wallet_permission',
  );

  /// Returns `true` if the user has granted notification-listener access.
  Future<bool> isPermissionGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('isPermissionGranted') ??
          false;
    } catch (e) {
      debugPrint('WalletNotificationService.isPermissionGranted error: $e');
      return false;
    }
  }

  /// Opens the Android system "Notification access" settings screen.
  Future<void> openPermissionSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _methodChannel.invokeMethod<void>('openPermissionSettings');
    } catch (e) {
      debugPrint('WalletNotificationService.openPermissionSettings error: $e');
    }
  }
}
