import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../../app/theme.dart';
import '../utils/format.dart';
import 'buttons.dart';
import 'common.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.keyboard,
    this.obscure = false,
    this.error,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.formatters,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.textStyle,
    this.fill,
    this.helper,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboard;
  final bool obscure;
  final String? error;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final TextStyle? textStyle;
  final Color? fill;
  final String? helper;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[Text(label!, style: T.label), const Gap(8)],
      TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        inputFormatters: formatters,
        readOnly: readOnly,
        onTap: onTap,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        cursorColor: C.primary,
        style: textStyle ?? T.bodyM.copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          prefixIcon: prefix == null ? null : Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: prefix),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.only(right: 10), child: suffix),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          errorText: error,
          errorStyle: T.small.copyWith(color: C.error, fontSize: 12),
          fillColor: fill,
          helperText: helper,
          helperStyle: T.small,
          helperMaxLines: 3,
        ),
      ),
    ]);
  }
}

/// Large ₦ amount input with min/max hint — used on every bill screen.
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, this.hint = 'Enter amount', this.onChanged, this.error});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        cursorColor: C.primary,
        style: T.moneyOf(22, w: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: T.moneyOf(18, w: FontWeight.w500, color: C.faint).copyWith(letterSpacing: 0),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Text(naira, style: T.moneyOf(22, w: FontWeight.w700)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          errorText: error,
          errorStyle: T.small.copyWith(color: C.error, fontSize: 12),
          fillColor: C.bg,
          enabledBorder: OutlineInputBorder(borderRadius: R.inputR, borderSide: BorderSide(color: error != null ? C.error : Colors.transparent)),
          border: OutlineInputBorder(borderRadius: R.inputR, borderSide: BorderSide.none),
        ),
      ),
    ]);
  }
}

/// 3-column grid of tappable quick-amount tiles.
class QuickAmountGrid extends StatelessWidget {
  const QuickAmountGrid({super.key, required this.amounts, required this.selected, required this.onSelect, this.subtitleOf, this.subtitleColor = C.primary});
  final List<int> amounts;
  final int? selected;
  final ValueChanged<int> onSelect;
  final String Function(int)? subtitleOf;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final a in amounts)
            SizedBox(
              width: w,
              child: Pressable(
                onTap: () => onSelect(a),
                haptic: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected == a ? C.tint : C.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected == a ? C.primary : Colors.transparent, width: 1.4),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(money(a), style: T.moneyOf(17, w: FontWeight.w700, color: selected == a ? C.primary : C.ink)),
                    if (subtitleOf != null) ...[
                      const Gap(3),
                      Text(subtitleOf!(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: subtitleColor, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Two-option segmented control (Prepaid / Postpaid etc.).
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({super.key, required this.options, required this.index, required this.onChanged});
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) const HGap(10),
        Expanded(
          child: Pressable(
            onTap: () => onChanged(i),
            haptic: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 50,
              decoration: BoxDecoration(
                color: i == index ? C.tint : C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i == index ? C.primary : C.border, width: i == index ? 1.4 : 1),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (i == index) ...[PhosphorIcon(PhosphorIconsBold.check, size: 15, color: C.primary), const HGap(6)],
                Text(options[i], style: T.title.copyWith(color: i == index ? C.primary : C.muted)),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Horizontal pill chips (categories, filters).
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.items, required this.index, required this.onChanged, this.padding = const EdgeInsets.symmetric(horizontal: Sp.page)});
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const HGap(8),
        itemBuilder: (_, i) {
          final sel = i == index;
          return Pressable(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? C.primary : C.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: sel ? C.primary : C.border),
              ),
              child: Text(items[i], style: T.label.copyWith(color: sel ? Colors.white : C.muted, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}

/// Numeric PIN keypad with dots. Calls [onComplete] with the 4 digits.
class PinEntry extends StatefulWidget {
  const PinEntry({super.key, required this.onComplete, this.length = 4, this.error});
  final ValueChanged<String> onComplete;
  final int length;
  final String? error;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void didUpdateWidget(covariant PinEntry old) {
    super.didUpdateWidget(old);
    if (widget.error != null && old.error != widget.error) {
      _shake.forward(from: 0);
      setState(() => _pin = '');
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String d) {
    HapticFeedback.selectionClick();
    if (_pin.length >= widget.length) return;
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      final p = _pin;
      Future.delayed(const Duration(milliseconds: 140), () => widget.onComplete(p));
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (_, child) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 9 * (1 - _shake.value), 0), child: child),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? (widget.error != null ? C.error : C.primary) : Colors.transparent,
                border: Border.all(color: i < _pin.length ? (widget.error != null ? C.error : C.primary) : C.border, width: 2),
              ),
            ),
        ]),
      ),
      SizedBox(height: 22, child: widget.error == null ? null : Center(child: Text(widget.error!, style: T.small.copyWith(color: C.error)))),
      const Gap(8),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.9,
        children: [
          for (final k in keys)
            if (k.isEmpty)
              const SizedBox()
            else
              Pressable(
                onTap: () => k == '<' ? _back() : _tap(k),
                scale: .92,
                child: Center(
                  child: k == '<'
                      ? PhosphorIcon(PhosphorIconsRegular.backspace, size: 26, color: C.ink)
                      : Text(k, style: T.moneyOf(26, w: FontWeight.w600)),
                ),
              ),
        ],
      ),
    ]);
  }
}
