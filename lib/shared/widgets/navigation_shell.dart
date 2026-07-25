import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/tokens/border_shadow_tokens.dart';

class NavigationShell extends StatelessWidget {
  final int currentIndex;
  final Widget body;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onFABPressed;
  final int? lowStockCount;
  final int? overdueCreditsCount;

  const NavigationShell({
    super.key,
    required this.currentIndex,
    required this.body,
    required this.onTabSelected,
    required this.onFABPressed,
    this.lowStockCount,
    this.overdueCreditsCount,
  });

  @override
  Widget build(BuildContext context) {
    const navBg = ColorTokens.lightSurfacePrimary;
    const borderColor = ColorTokens.lightBorderSubtle;
    const primaryBrand = ColorTokens.lightBrandPrimary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: navBg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: body,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: navBg,
            border: Border(
              top: BorderSide(color: borderColor, width: 1.0),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavButton(
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view,
                    label: 'Inicio',
                    isSelected: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),

                  _buildNavButton(
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2,
                    label: 'Inventario',
                    isSelected: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                    badgeCount: lowStockCount,
                    badgeColor: ColorTokens.statusWarning,
                  ),

                  Expanded(
                    child: Center(
                      child: InkWell(
                        onTap: onFABPressed,
                        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusPill),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryBrand,
                            shape: BoxShape.circle,
                            boxShadow: BorderShadowTokens.shadowLevel2,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                  _buildNavButton(
                    icon: Icons.credit_card_outlined,
                    activeIcon: Icons.credit_card,
                    label: 'Crédito',
                    isSelected: currentIndex == 2,
                    onTap: () => onTabSelected(2),
                    badgeCount: overdueCreditsCount,
                    badgeColor: ColorTokens.statusDanger,
                  ),

                  _buildNavButton(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long,
                    label: 'Ventas',
                    isSelected: currentIndex == 3,
                    onTap: () => onTabSelected(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
    Color badgeColor = ColorTokens.statusWarning,
  }) {
    final color = isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: FontTokens.bodySmall.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 6,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(BorderShadowTokens.radiusPill),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: FontTokens.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


