import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/widgets/transaction_form.dart';
import 'package:expenses_tracker/widgets/transaction_list.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class IncomesScreen extends StatelessWidget {
  final List<Transaction>? incomes;
  final Function(Transaction) onAddIncome;
  final Function(Transaction) onEditIncome;
  final Function(String, TransactionType) onRemoveTransaction;

  const IncomesScreen({
    super.key,
    required this.incomes,
    required this.onAddIncome,
    required this.onEditIncome,
    required this.onRemoveTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          incomes == null
              ? const Center(child: CircularProgressIndicator())
              : incomes!.isEmpty
              ? _buildEmptyState()
              : TransactionList(
                transactions: incomes!,
                transactionType: TransactionType.income,
                onRemoveTransaction: onRemoveTransaction,
                onEditTransaction:
                    (transaction) => _showEditIncomeForm(context, transaction),
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.income,
        foregroundColor: Colors.white,
        onPressed: () => _showAddIncomeForm(context),
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
            'assets/income_icon.png',
            width: 80,
            height: 80,
            color: AppColors.income.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'No incomes recorded',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add an income',
            style: TextStyle(fontSize: 15, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  void _showAddIncomeForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionForm(
            transactionType: TransactionType.income,
            onSave: onAddIncome,
          ),
    );
  }

  void _showEditIncomeForm(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionForm(
            transactionType: TransactionType.income,
            initialTransaction: transaction,
            onSave: onEditIncome,
          ),
    );
  }
}
