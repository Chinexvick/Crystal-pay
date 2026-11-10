import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../../core/utils/pick_photos.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/account.dart';

/// Round profile photo with a camera badge. Tapping it opens the camera or gallery.
class ProfilePhotoPicker extends ConsumerWidget {
  const ProfilePhotoPicker({super.key, this.size = 92, this.nameOverride});
  final double size;
  final String? nameOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(accountProvider);
    final name = (nameOverride ?? a.fullName).trim();
    return Pressable(
      onTap: () async {
        final got = await pickPhotos(context);
        if (got.isNotEmpty) ref.read(accountProvider.notifier).setPhoto(got.first);
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Avatar(asset: a.photo, name: name.isEmpty ? 'You' : name, size: size, verified: a.idVerified),
        Positioned(
          right: -2,
          bottom: 0,
          child: Container(
            width: size * .34,
            height: size * .34,
            decoration: BoxDecoration(color: C.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Center(child: PhosphorIcon(PhosphorIconsBold.camera, size: size * .17, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
