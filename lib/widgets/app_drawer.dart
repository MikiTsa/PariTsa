import 'package:flutter/material.dart';
import 'package:expenses_tracker/screens/sidebar/categories_screen.dart';
import 'package:expenses_tracker/screens/sidebar/history_screen.dart';
import 'package:expenses_tracker/screens/sidebar/analytics_screen.dart';
import 'package:expenses_tracker/screens/sidebar/profile_screen.dart';
import 'package:expenses_tracker/screens/sidebar/settings_screen.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'PariTsa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Personal Finance Tracker',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Nav items
            _DrawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => _navigate(context, const ProfileScreen()),
            ),
            _DrawerItem(
              icon: Icons.history,
              label: 'History',
              onTap: () => _navigate(context, const HistoryScreen()),
            ),
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              onTap: () => _navigate(context, const AnalyticsScreen()),
            ),
            _DrawerItem(
              icon: Icons.category_outlined,
              label: 'Categories',
              onTap: () => _navigate(context, const CategoriesScreen()),
            ),

            const Spacer(),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 4),

            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => _navigate(context, const SettingsScreen()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryText, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      horizontalTitleGap: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
