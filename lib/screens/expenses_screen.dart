import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/widgets/transaction_form.dart';
import 'package:expenses_tracker/widgets/transaction_list.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class ExpensesScreen extends StatefulWidget {
  final List<Transaction>? expenses;
  final Function(Transaction) onAddExpense;
  final Function(Transaction) onEditExpense;
  final Function(String, TransactionType) onRemoveTransaction;
  final Future<void> Function(Transaction)? onMoveToShared;
  final Future<void> Function(List<String>)? onRemoveMultiple;
  final Future<void> Function(List<Transaction>)? onMoveMultipleToShared;
  final void Function(bool)? onSelectionModeChanged;

  const ExpensesScreen({
    super.key,
    required this.expenses,
    required this.onAddExpense,
    required this.onEditExpense,
    required this.onRemoveTransaction,
    this.onMoveToShared,
    this.onRemoveMultiple,
    this.onMoveMultipleToShared,
    this.onSelectionModeChanged,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isSelecting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          widget.expenses == null
              ? const Center(child: CircularProgressIndicator())
              : widget.expenses!.isEmpty
              ? _buildEmptyState()
              : TransactionList(
                transactions: widget.expenses!,
                transactionType: TransactionType.expense,
                onRemoveTransaction: widget.onRemoveTransaction,
                onEditTransaction:
                    (transaction) => _showEditExpenseForm(context, transaction),
                onMoveToShared: widget.onMoveToShared,
                onRemoveMultiple: widget.onRemoveMultiple,
                onMoveMultipleToShared: widget.onMoveMultipleToShared,
                onSelectionModeChanged: (selecting) {
                  setState(() => _isSelecting = selecting);
                  widget.onSelectionModeChanged?.call(selecting);
                },
              ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              onPressed: () => _showAddExpenseForm(context),
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
            'assets/expense_icon.png',
            width: 80,
            height: 80,
            color: AppColors.expense.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add an expense',
            style: TextStyle(fontSize: 15, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionForm(
            transactionType: TransactionType.expense,
            onSave: widget.onAddExpense,
          ),
    );
  }

  void _showEditExpenseForm(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionForm(
            transactionType: TransactionType.expense,
            initialTransaction: transaction,
            onSave: widget.onEditExpense,
          ),
    );
  }
}
