import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../widgets/common.dart';

/// Lets the user take a photo or choose from the gallery. Returns file paths
/// (blob URLs on web). Uses the system pickers, so no storage permission is
/// requested. Images are downscaled before upload.
Future<List<String>> pickPhotos(BuildContext context, {int max = 1}) async {
  final src = await showAppSheet<ImageSource>(
    context,
    builder: (ctx) => SheetFrame(
      title: max > 1 ? 'Add photos' : 'Add a photo',
      child: Column(children: [
        _Opt(PhosphorIconsDuotone.camera, 'Take a photo', () => Navigator.pop(ctx, ImageSource.camera)),
        _Opt(PhosphorIconsDuotone.image, max > 1 ? 'Choose from gallery' : 'Choose from gallery', () => Navigator.pop(ctx, ImageSource.gallery)),
      ]),
    ),
  );
  if (src == null) return const [];
  try {
    final picker = ImagePicker();
    if (src == ImageSource.camera) {
      final f = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 82);
      return f == null ? const [] : [f.path];
    }
    if (max > 1) {
      final l = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 82, limit: max);
      return [for (final f in l.take(max)) f.path];
    }
    final f = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    return f == null ? const [] : [f.path];
  } catch (_) {
    if (context.mounted) showToast(context, 'Could not open your photos. Check app permissions.', error: true);
    return const [];
  }
}

class _Opt extends StatelessWidget {
  const _Opt(this.icon, this.label, this.onTap);
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconChip(icon, size: 44, circle: true, iconSize: 22),
        title: Text(label, style: T.title),
        onTap: onTap,
      );
}
