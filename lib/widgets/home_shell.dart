import 'package:flutter/material.dart';

import '../agent/agent.dart';
import '../theme/app_theme.dart';
import 'chat_list_screen.dart';
import 'placeholder_tab.dart';

/// The root WeChat-style scaffold: a body that swaps per tab and an animated
/// bottom tab bar. Only the Chats tab is wired to real functionality today.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.hub});

  final Agent hub;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <_TabSpec>[
    _TabSpec('Chats', Icons.chat_bubble, Icons.chat_bubble_outline),
    _TabSpec('Contacts', Icons.contacts, Icons.contacts_outlined),
    _TabSpec('Discover', Icons.explore, Icons.explore_outlined),
    _TabSpec('Me', Icons.person, Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _buildTab(_index),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        tabs: _tabs,
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return ChatListScreen(hub: widget.hub);
      case 1:
        return const PlaceholderTab(
          title: 'Contacts',
          icon: Icons.contacts_outlined,
          message: 'Your people will live here soon.',
        );
      case 2:
        return const PlaceholderTab(
          title: 'Discover',
          icon: Icons.explore_outlined,
          message: 'Fun things to explore are on the way.',
        );
      default:
        return const PlaceholderTab(
          title: 'Me',
          icon: Icons.person_outline,
          message: 'Your profile and settings will appear here.',
        );
    }
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.activeIcon, this.idleIcon);
  final String label;
  final IconData activeIcon;
  final IconData idleIcon;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bar,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset, top: 6),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _TabButton(
                spec: tabs[i],
                selected: i == index,
                showBadge: i == 0,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pop.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? AppColors.brand : AppColors.tabIdle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.28).animate(
                CurvedAnimation(
                  parent: _pop,
                  curve: Curves.elasticOut,
                  reverseCurve: Curves.easeIn,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.selected
                          ? widget.spec.activeIcon
                          : widget.spec.idleIcon,
                      key: ValueKey(widget.selected),
                      color: color,
                      size: 26,
                    ),
                  ),
                  if (widget.showBadge)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.badge,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(widget.spec.label),
            ),
          ],
        ),
      ),
    );
  }
}
