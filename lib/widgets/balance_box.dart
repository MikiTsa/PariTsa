import 'package:flutter/material.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class BalanceBox extends StatelessWidget {
  final double amount;
  final bool isSavings;
  final int activeTabIndex;

  const BalanceBox({
    super.key,
    required this.amount,
    required this.isSavings,
    required this.activeTabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final String formattedAmount = amount.toStringAsFixed(2);
    final Color base = _getBaseColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.30),
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
            '\$$formattedAmount',
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

  Color _getBaseColor() {
    switch (activeTabIndex) {
      case 0:
        return AppColors.balanceExpense;
      case 1:
        return AppColors.balanceIncome;
      case 2:
        return AppColors.balanceSaving;
      default:
        return AppColors.balticBlue;
    }
  }
}
