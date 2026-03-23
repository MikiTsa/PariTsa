import 'package:flutter/material.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_outlined, size: 64, color: AppColors.mutedText),
            SizedBox(height: 16),
            Text(
              'Coming soon',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
