import 'package:flutter/material.dart';

import 'mindmate_theme.dart';

/// The bar at the bottom of the five main tabs: white, rounded at the top,
/// with the open tab on a gold pill.
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('Home', Icons.home_outlined, Icons.home_rounded),
    _Tab(
      'Mood',
      Icons.sentiment_satisfied_alt_outlined,
      Icons.sentiment_satisfied_alt_rounded,
    ),
    _Tab(
      'AI Chat',
      Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded,
    ),
    _Tab('Journal', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _Tab('Settings', Icons.tune_rounded, Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final MindMateColors c = context.mm;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: c.surfaceBorder == null
            ? null
            : Border(top: BorderSide(color: c.surfaceBorder!)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.shadow,
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < _tabs.length; i += 1)
                Expanded(
                  child: _NavItem(
                    tab: _tabs[i],
                    selected: selectedIndex == i,
                    onTap: () => onTabChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // heightFactor keeps each item as tall as its content: a plain Center
        // would stretch to the whole screen.
        child: Align(
          heightFactor: 1,
          child: AnimatedContainer(
            duration: AppMotion.of(context, const Duration(milliseconds: 220)),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minWidth: 62, minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              gradient: selected ? AppBlends.gold : null,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: 24,
                  color: selected ? AppColors.headerBlue : context.mm.textMuted,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    style: AppFonts.body(
                      size: 12.5,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.headerBlue
                          : context.mm.textMuted,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
