import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crystal_pay/core/icons/phosphor.dart';

import '../core/widgets/buttons.dart';
import 'theme.dart';

/// Four-tab bottom bar from the approved designs: Home · Shop · Bills · More.
/// The active tab is purple with a short underline beneath its label.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = <_NavItem>[
    _NavItem('Home', PhosphorIconsRegular.house, PhosphorIconsFill.house),
    _NavItem('Shop', PhosphorIconsRegular.shoppingBagOpen, PhosphorIconsFill.shoppingBagOpen),
    _NavItem('Bills', PhosphorIconsRegular.receipt, PhosphorIconsFill.receipt),
    _NavItem('More', PhosphorIconsRegular.squaresFour, PhosphorIconsFill.squaresFour),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      extendBody: false,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: const Color(0xFF3B1A8C).withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: _items[i],
                    selected: shell.currentIndex == i,
                    onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final PhosphorIconData icon;
  final PhosphorIconData activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? C.primary : const Color(0xFF8A85A3);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: .92,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 4),
          PhosphorIcon(selected ? item.activeIcon : item.icon, size: 25, color: color),
          const SizedBox(height: 4),
          Text(item.label, style: TextStyle(fontFamily: T.family, fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color)),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: selected ? 34 : 0,
            height: 3,
            decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(2)),
          ),
        ]),
      ),
    );
  }
}
