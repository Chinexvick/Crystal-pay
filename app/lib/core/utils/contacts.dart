import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../../app/theme.dart';
import '../widgets/common.dart';

/// "+234 803 000 0001" / "234803…" / "0803…" → "08030000001". Null if not a Nigerian mobile.
String? normaliseNgNumber(String raw) {
  var d = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (d.startsWith('+234')) {
    d = '0${d.substring(4)}';
  } else if (d.startsWith('234') && d.length == 13) {
    d = '0${d.substring(3)}';
  }
  d = d.replaceAll('+', '');
  return RegExp(r'^0[789][01]\d{8}$').hasMatch(d) ? d : null;
}

/// Opens the phone's own contact picker (no contacts permission needed: the
/// system returns only the one contact the user taps). Where no native picker
/// exists (web preview) a small sample list is shown instead.
Future<String?> pickPhoneContact(BuildContext context) async {
  if (!kIsWeb) {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      if (c == null) return null;
      final n = normaliseNgNumber(c.selectedPhoneNumber ?? (c.phoneNumbers?.isNotEmpty == true ? c.phoneNumbers!.first : ''));
      if (n == null && context.mounted) showToast(context, 'That contact does not have a valid Nigerian mobile number', error: true);
      return n;
    } catch (_) {
      return null;
    }
  }
  return showAppSheet<String>(
    context,
    builder: (ctx) => SheetFrame(
      title: 'Choose a contact',
      child: Column(children: [
        for (final c in const [('Mum', '08031234567'), ('Chinedu Okafor', '08055550123'), ('Amaka Eze', '09012345678'), ('Tunde Bakare', '08166667788')])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Avatar(name: c.$1, size: 40),
            title: Text(c.$1, style: T.bodyM),
            subtitle: Text(c.$2, style: T.small),
            onTap: () => Navigator.pop(ctx, c.$2),
          ),
      ]),
    ),
  );
}
