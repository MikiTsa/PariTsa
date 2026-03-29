import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/widgets/transaction_form.dart';
import 'package:expenses_tracker/widgets/transaction_list.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class SavingsScreen extends StatelessWidget {
  final List<Transaction>? savings;
  final Function(Transaction) onAddSaving;
  final Function(Transaction) onEditSaving;
  final Function(String, TransactionType) onRemoveTransaction;

  const SavingsScreen({
    super.key,
    required this.savings,
    required this.onAddSaving,
    required this.onEditSaving,
    required this.onRemoveTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          savings == null
              ? const Center(child: CircularProgressIndicator())
              : savings!.isEmpty
              ? _buildEmptyState()
              : TransactionList(
                transactions: savings!,
                transactionType: TransactionType.saving,
                onRemoveTransaction: onRemoveTransaction,
                onEditTransaction:
                    (transaction) => _showEditSavingForm(context, transaction),
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.saving,
        foregroundColor: Colors.white,
        onPressed: () => _showAddSavingForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/saving_icon.png',
            width: 80,
            height: 80,
            color: AppColors.saving.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No savings recorded',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add a saving',
            style: TextStyle(fontSize: 15, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  void _showAddSavingForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionForm(
            transactionType: TransactionType.saving,
            onSave: onAddSaving,
          ),
    );
  }

  void _showEditSavingForm(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionForm(
            transactionType: TransactionType.saving,
            initialTransaction: transaction,
            onSave: onEditSaving,
          ),
    );
  }
}
