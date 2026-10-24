import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native privacy hooks. On Android, `setSecure` toggles
/// `WindowManager.LayoutParams.FLAG_SECURE` (blank app-switcher thumbnail,
/// no screenshots or screen recording). See `MainActivity.kt`.
class PrivacyChannel {
  const PrivacyChannel([this._channel = const MethodChannel(name)]);

  static const name = 'personal_finance/privacy';

  final MethodChannel _channel;

  /// Whether this platform implements [setSecure].
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> setSecure({required bool secure}) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Older native shell without the channel.
    } on PlatformException catch (e) {
      debugPrint('FLAG_SECURE could not be set: $e');
    }
  }
}

final privacyChannelProvider = Provider<PrivacyChannel>(
  (ref) => const PrivacyChannel(),
);
