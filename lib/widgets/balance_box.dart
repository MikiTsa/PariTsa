import 'package:flutter/material.dart';
import 'package:expenses_tracker/providers/app_settings.dart';

class BalanceBox extends StatelessWidget {
  final double amount;
  final bool isSavings;
  final Color baseColor;

  const BalanceBox({
    super.key,
    required this.amount,
    required this.isSavings,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final String formatted = settings.formatAmount(amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSavings ? 'Total Savings' : 'Current Balance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
