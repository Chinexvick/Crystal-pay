import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';

/// Gives any child a subtle press-scale + haptic feedback.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = .97, this.haptic = false});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

enum BtnKind { primary, secondary, soft, danger, onDark }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = BtnKind.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 54,
    this.small = false,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final PhosphorIconData? icon;
  final bool loading;
  final bool expand;
  final double height;
  final bool small;

  /// Icon after the label, e.g. "Next →".
  final PhosphorIconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    late Color bg, fg;
    Color? border;
    switch (kind) {
      case BtnKind.primary:
        bg = C.primary;
        fg = Colors.white;
        break;
      case BtnKind.secondary:
        bg = C.surface;
        fg = C.primary;
        border = C.primary.withValues(alpha: .35);
        break;
      case BtnKind.soft:
        bg = C.tint;
        fg = C.primary;
        break;
      case BtnKind.danger:
        bg = C.errorTint;
        fg = C.error;
        break;
      case BtnKind.onDark:
        bg = Colors.white;
        fg = C.primaryDark;
        break;
    }
    final h = small ? 40.0 : height;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg, strokeCap: StrokeCap.round))
        else ...[
          if (icon != null) ...[PhosphorIcon(icon!, size: small ? 18 : 20, color: fg), const SizedBox(width: 8)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.button.copyWith(color: fg, fontSize: small ? 13.5 : 15.5)),
          ),
          if (trailingIcon != null) ...[const SizedBox(width: 8), PhosphorIcon(trailingIcon!, size: small ? 16 : 18, color: fg)],
        ]
      ],
    );
    final box = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: (onPressed == null && !loading) ? .38 : 1,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(small ? 999 : 16),
          border: border == null ? null : Border.all(color: border, width: 1.2),
        ),
        child: child,
      ),
    );
    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: true,
      child: expand ? SizedBox(width: double.infinity, child: box) : box,
    );
  }
}

/// Small tappable text, e.g. "See all".
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, this.onTap, this.color = C.primary, this.trailing = true, this.arrow = false});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool trailing;

  /// Show a straight arrow (section "See All →") instead of a caret.
  final bool arrow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: T.label.copyWith(color: color, fontWeight: FontWeight.w700)),
          if (arrow) ...[const SizedBox(width: 5), PhosphorIcon(PhosphorIconsBold.arrowRight, size: 15, color: color)]
          else if (trailing) ...[const SizedBox(width: 2), PhosphorIcon(PhosphorIconsBold.caretRight, size: 13, color: color)],
        ]),
      ),
    );
  }
}

/// Round icon button used in headers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onTap, this.badge, this.dot = false, this.bg = C.surface, this.fg = C.ink, this.size = 42});
  final PhosphorIconData icon;
  final VoidCallback? onTap;
  final int? badge;
  final bool dot;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: bg == C.surface ? Border.all(color: C.border) : null,
            ),
            child: Center(child: PhosphorIcon(icon, size: size * .5, color: fg)),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                    color: C.error, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.bg, width: 2)),
                alignment: Alignment.center,
                child: Text(badge! > 99 ? '99+' : '$badge',
                    style: const TextStyle(fontFamily: T.family, color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.1)),
              ),
            ),
          if (dot)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: C.error, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 2))),
            ),
        ]),
      ),
    );
  }
}
