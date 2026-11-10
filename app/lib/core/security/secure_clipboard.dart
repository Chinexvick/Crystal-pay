import 'dart:async';

import 'package:flutter/services.dart';

import '../config/app_config.dart';

Timer? _wipe;

/// Copies [text] and clears the clipboard after a short delay, but only if it
/// still holds the same value (so we never wipe something the user copied later).
Future<void> copySensitive(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  _wipe?.cancel();
  _wipe = Timer(Security.clipboardClearAfter, () async {
    final cur = await Clipboard.getData(Clipboard.kTextPlain);
    if (cur?.text == text) await Clipboard.setData(const ClipboardData(text: ''));
  });
}
