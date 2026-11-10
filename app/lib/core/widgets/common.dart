import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../utils/format.dart';
import 'buttons.dart';

// ───────────────────────── Layout helpers ─────────────────────────

class Gap extends StatelessWidget {
  const Gap(this.h, {super.key, this.w = 0});
  final double h;
  final double w;
  @override
  Widget build(BuildContext context) => SizedBox(height: h, width: w);
}

class HGap extends StatelessWidget {
  const HGap(this.w, {super.key});
  final double w;
  @override
  Widget build(BuildContext context) => SizedBox(width: w);
}

/// A white rounded card with hairline border & soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = C.surface, this.shadow = false, this.radius = R.card, this.borderColor = C.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final bool shadow;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadow ? softShadow() : null,
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: .985, child: box);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 12), this.trailing});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: T.h2.copyWith(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.4))),
        ?trailing,
        if (action != null) TextLink(action!, onTap: onAction, arrow: true),
      ]),
    );
  }
}

// ───────────────────────── Icons & badges ─────────────────────────

/// Duotone icon on a soft tinted tile — the app's signature icon treatment.
class IconChip extends StatelessWidget {
  const IconChip(this.icon, {super.key, this.size = 48, this.bg = C.tint, this.fg = C.primary, this.circle = false, this.iconSize});
  final PhosphorIconData icon;
  final double size;
  final Color bg;
  final Color fg;
  final bool circle;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * .32),
      ),
      child: Center(child: PhosphorIcon(icon, size: iconSize ?? size * .5, color: fg)),
    );
  }
}

enum Status { success, pending, failed }

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final Status status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text) = switch (status) {
      Status.success => (C.successTint, C.success, 'Successful'),
      Status.pending => (C.goldTint, C.pending, 'Pending'),
      Status.failed => (C.errorTint, C.error, 'Failed'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == Status.success) ...[PhosphorIcon(PhosphorIconsFill.checkCircle, size: 12, color: fg), const SizedBox(width: 3)],
        Text(label ?? text, style: T.caption.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.bg = C.tint, this.fg = C.primary, this.icon});
  final String text;
  final Color bg;
  final Color fg;
  final PhosphorIconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[PhosphorIcon(icon!, size: 12, color: fg), const SizedBox(width: 4)],
        Text(text, style: T.caption.copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );
  }
}

/// Provider / biller logo. Uses a bundled logo asset when available,
/// otherwise a clean monogram badge.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({super.key, this.asset, required this.name, this.size = 44, this.color});
  final String? asset;
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.border)),
        child: ClipOval(child: Image.asset(asset!, width: size, height: size, fit: BoxFit.cover, filterQuality: FilterQuality.medium)),
      );
    }
    final c = color ?? C.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: .12),
      ),
      alignment: Alignment.center,
      child: Text(
        _mono(name),
        style: TextStyle(fontFamily: T.family, fontSize: size * .34, fontWeight: FontWeight.w800, color: c, letterSpacing: -.3),
      ),
    );
  }

  String _mono(String n) {
    final parts = n.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Brand 3D icon (assets/icons3d/NAME.webp). One consistent set is used
/// for bills, categories, quick actions and menus.
class Icon3D extends StatelessWidget {
  const Icon3D(this.name, {super.key, this.size = 40});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset('assets/icons3d/$name.webp', width: size, height: size, filterQuality: FilterQuality.medium, gaplessPlayback: true);
}

/// Bill service icon (same 3D set).
class ServiceIcon extends StatelessWidget {
  const ServiceIcon(this.name, {super.key, this.size = 52});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Icon3D(name, size: size);
}

/// A tinted rounded tile holding a 3D icon, as used across the designs.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 48, this.bg = C.tint, this.iconSize});
  final String icon;
  final double size;
  final Color bg;
  final double? iconSize;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .3)),
        alignment: Alignment.center,
        child: Icon3D(icon, size: iconSize ?? size * .66),
      );
}

/// Real bank logo by CBN/NIBSS code (bundled in assets/banks), with a
/// monogram fallback for banks we have no artwork for.
class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.code, required this.name, this.size = 44});
  final String code, name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: C.border)),
      child: ClipOval(
        child: Image.asset(
          'assets/banks/$code.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => ProviderLogo(name: name, size: size),
        ),
      ),
    );
  }
}

/// Resolves a bundled asset, a web blob/URL or a picked file on the device.
ImageProvider imageFor(String path) {
  if (path.startsWith('assets/')) return AssetImage(path);
  if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) return NetworkImage(path);
  return FileImage(File(path));
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.asset, required this.name, this.size = 44, this.verified = false});
  final String? asset;
  final String name;
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final inner = asset != null
        ? ClipOval(child: Image(image: imageFor(asset!), width: size, height: size, fit: BoxFit.cover, alignment: Alignment.topCenter))
        : Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: C.skyGradient),
            alignment: Alignment.center,
            child: Text(initials(name), style: TextStyle(fontFamily: T.family, color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .36)),
          );
    if (!verified) return inner;
    return Stack(clipBehavior: Clip.none, children: [
      inner,
      Positioned(
        right: -2,
        bottom: -2,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          padding: const EdgeInsets.all(1.5),
          child: PhosphorIcon(PhosphorIconsFill.sealCheck, size: size * .32, color: C.primary),
        ),
      ),
    ]);
  }
}

// ───────────────────────── App bar ─────────────────────────

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.actionLabel, this.onAction, this.actions, this.showBack = true, this.bg = C.surface, this.onBack, this.divider = false});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget>? actions;
  final bool showBack;
  final Color bg;
  final VoidCallback? onBack;
  final bool divider;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: C.border)) : null),
          padding: const EdgeInsets.only(left: 6, right: Sp.page - 4),
          child: Row(children: [
            if (showBack)
              Pressable(
                onTap: onBack ?? () => context.canPop() ? context.pop() : context.go('/home'),
                child: const SizedBox(width: 46, height: 46, child: Center(child: PhosphorIcon(PhosphorIconsBold.caretLeft, size: 21, color: C.ink))),
              )
            else
              const SizedBox(width: Sp.page - 6),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.h3)),
            if (actionLabel != null) TextLink(actionLabel!, onTap: onAction, trailing: false),
            ...?actions,
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Sheets & toasts ─────────────────────────

Future<V?> showAppSheet<V>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true, Color? barrier}) {
  return showModalBottomSheet<V>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: C.surface,
    barrierColor: barrier ?? C.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
    builder: builder,
  );
}

/// Standard sheet chrome: drag handle, title row with close, content.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, this.title, required this.child, this.showClose = true, this.padding = const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 20), this.leading});
  final String? title;
  final Widget child;
  final bool showClose;
  final EdgeInsetsGeometry padding;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Gap(10),
        Container(width: 38, height: 4.5, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(3))),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 14, Sp.page - 8, 6),
            child: Row(children: [
              if (leading != null) ...[leading!, const HGap(10)],
              Expanded(child: Text(title!, style: T.h3)),
              if (showClose)
                Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(width: 44, height: 44, child: Center(child: PhosphorIcon(PhosphorIconsBold.x, size: 18, color: C.muted))),
                ),
            ]),
          )
        else
          const Gap(10),
        Flexible(child: SingleChildScrollView(padding: padding, child: child)),
      ]),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false, PhosphorIconData? icon}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    backgroundColor: error ? C.error : C.navy,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(milliseconds: 2600),
    content: Row(children: [
      PhosphorIcon(icon ?? (error ? PhosphorIconsFill.warningCircle : PhosphorIconsFill.checkCircle), color: Colors.white, size: 20),
      const HGap(10),
      Expanded(child: Text(message, style: T.bodyM.copyWith(color: Colors.white))),
    ]),
  ));
}

// ───────────────────────── Empty / info ─────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final PhosphorIconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(color: C.tint, shape: BoxShape.circle),
            child: Center(child: PhosphorIcon(icon, size: 42, color: C.primary)),
          ),
          const Gap(20),
          Text(title, style: T.h3, textAlign: TextAlign.center),
          const Gap(6),
          Text(message, style: T.small.copyWith(fontSize: 13.5), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const Gap(22),
            AppButton(label: actionLabel!, onPressed: onAction, expand: false, small: true),
          ],
        ]),
      ),
    );
  }
}

/// Inline alert banner (info / warning / error).
class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.kind = BannerKind.info, this.icon, this.action, this.onAction});
  final String text;
  final BannerKind kind;
  final PhosphorIconData? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic) = switch (kind) {
      BannerKind.info => (C.tint, C.primary, PhosphorIconsFill.info),
      BannerKind.warning => (C.goldTint, C.pending, PhosphorIconsFill.warning),
      BannerKind.error => (C.errorTint, C.error, PhosphorIconsFill.warningCircle),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: PhosphorIcon(icon ?? ic, size: 18, color: fg)),
        const HGap(10),
        Expanded(child: Text(text, style: T.small.copyWith(color: C.ink, fontSize: 12.5))),
        if (action != null) ...[const HGap(8), TextLink(action!, onTap: onAction, color: fg, trailing: false)],
      ]),
    );
  }
}

enum BannerKind { info, warning, error }

/// Key–value row used in confirm sheets & receipts.
class KvRow extends StatelessWidget {
  const KvRow(this.k, this.v, {super.key, this.valueWidget, this.valueColor, this.bold = false, this.copyable = false});
  final String k;
  final String? v;
  final Widget? valueWidget;
  final Color? valueColor;
  final bool bold;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(k, style: T.small.copyWith(fontSize: 13.5)),
        const HGap(16),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: valueWidget ??
                Text(v ?? '',
                    textAlign: TextAlign.right,
                    style: T.bodyM.copyWith(color: valueColor ?? C.ink, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ),
        ),
      ]),
    );
  }
}

class HairDivider extends StatelessWidget {
  const HairDivider({super.key, this.indent = 0});
  final double indent;
  @override
  Widget build(BuildContext context) => Container(height: 1, margin: EdgeInsets.only(left: indent), color: C.border);
}

/// Rounded search-style pill used as a button.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.hint, this.onTap});
  final String hint;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF2EFF8), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: C.muted),
          const HGap(10),
          Expanded(child: Text(hint, style: T.body.copyWith(color: C.faint), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10)),
            child: Center(child: PhosphorIcon(PhosphorIconsBold.slidersHorizontal, size: 16, color: C.primary)),
          ),
        ]),
      ),
    );
  }
}
