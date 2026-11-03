import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer on [phone]. Returns false when no dialer opened
/// (no telephony app, plugin missing, or the launch failed), so the caller
/// can fall back to copying the number.
typedef PhoneDialer = Future<bool> Function(String phone);

/// `tel:` URI for [phone], keeping only digits and a leading `+`, the same
/// number the website puts in `href="tel:…"`.
Uri telUri(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return Uri(
    scheme: 'tel',
    path: trimmed.startsWith('+') ? '+$digits' : digits,
  );
}

Future<bool> launchDialer(String phone) async {
  try {
    return await launchUrl(telUri(phone), mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  } catch (_) {
    return false;
  }
}

final phoneDialerProvider = Provider<PhoneDialer>((ref) => launchDialer);
