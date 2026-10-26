import 'package:flutter/material.dart';

const _navInk = Color(0xFF19456B);

class TravelBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const TravelBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82 + MediaQuery.paddingOf(context).bottom,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _navInk.withValues(alpha: 0.16))),
        boxShadow: [
          BoxShadow(
            color: _navInk.withValues(alpha: 0.16),
            blurRadius: 16,
            spreadRadius: -3,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  isSelected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.favorite_border_rounded,
                  label: 'Favorites',
                  isSelected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ),
              Expanded(
                child: Center(child: _AddNavButton(onTap: () => onSelected(2))),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.smart_display_outlined,
                  label: 'Videos',
                  isSelected: selectedIndex == 3,
                  onTap: () => onSelected(3),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  isSelected: selectedIndex == 4,
                  onTap: () => onSelected(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = _navInk;
    const inactiveColor = Color(0xFF6F7C88);
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 30,
            decoration: BoxDecoration(
              color: isSelected ? _navInk.withValues(alpha: 0.16) : null,
              borderRadius: BorderRadius.circular(999),
              border: isSelected
                  ? Border.all(color: _navInk.withValues(alpha: 0.18))
                  : null,
            ),
            child: Icon(icon, color: color, size: isSelected ? 22 : 21),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'NotoSansThai',
              color: color,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const buttonColor = _navInk;

    return Material(
      color: buttonColor,
      shape: const CircleBorder(),
      elevation: 10,
      shadowColor: buttonColor.withValues(alpha: 0.38),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
