import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final TransactionType transactionType;
  final Function(String, TransactionType)? onRemoveTransaction;
  final Function(Transaction)? onEditTransaction;

  const TransactionList({
    super.key,
    required this.transactions,
    required this.transactionType,
    this.onRemoveTransaction,
    this.onEditTransaction,
  });

  Color get typeColor {
    switch (transactionType) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.saving:
        return AppColors.saving;
    }
  }

  String get typeIconPath {
    switch (transactionType) {
      case TransactionType.expense:
        return 'assets/expense_icon.png';
      case TransactionType.income:
        return 'assets/income_icon.png';
      case TransactionType.saving:
        return 'assets/saving_icon.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTransactions = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedTransactions.length,
      itemBuilder: (context, index) {
        final transaction = sortedTransactions[index];

        final bool isFirstOfDay =
            index == 0 ||
            !DateUtils.isSameDay(
              transaction.date,
              sortedTransactions[index - 1].date,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstOfDay) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  _formatDateHeader(transaction.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Divider(color: AppColors.divider, thickness: 1),
            ],

            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: typeColor.withValues(alpha: 0.15),
                  child: Image.asset(
                    typeIconPath,
                    width: 22,
                    height: 22,
                    color: typeColor,
                  ),
                ),
                title: Text(
                  transaction.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                subtitle: Wrap(
                  spacing: 6,
                  children: [
                    Text(
                      transaction.category ?? 'No category',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    if (transaction.tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.tag!,
                          style: TextStyle(
                            fontSize: 11,
                            color: typeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: typeColor,
                      ),
                    ),
                    Text(
                      DateFormat.jm().format(transaction.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                onTap: () => _showTransactionDetails(context, transaction),
                onLongPress: () => _confirmDelete(context, transaction),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(
      date,
      DateTime(now.year, now.month, now.day - 1),
    )) {
      return 'Yesterday';
    }
    if (date.isAfter(DateTime(now.year, now.month, now.day - 7))) {
      return DateFormat.EEEE().format(date);
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  void _confirmDelete(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Are you sure you want to delete "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onRemoveTransaction != null) {
                onRemoveTransaction!(transaction.id, transactionType);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.deleteAction),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.pearlAqua,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: typeColor.withValues(alpha: 0.15),
                  radius: 24,
                  child: Image.asset(
                    typeIconPath,
                    width: 28,
                    height: 28,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd().add_jm().format(transaction.date),
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (transaction.category != null) ...[
                        _buildDetailRow(
                          Icons.category_outlined,
                          'Category',
                          transaction.category!,
                        ),
                        if (transaction.note != null)
                          const SizedBox(height: 12),
                      ],
                      if (transaction.note != null)
                        _buildDetailRow(
                          Icons.note_outlined,
                          'Note',
                          transaction.note!,
                        ),
                      if (transaction.tag != null) ...[
                        if (transaction.category != null || transaction.note != null)
                          const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.label_outline,
                          'Tag',
                          transaction.tag!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onEditTransaction != null) {
                      onEditTransaction!(transaction);
                    }
                  },
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  child: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.darkCyan, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
