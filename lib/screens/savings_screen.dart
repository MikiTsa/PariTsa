import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/widgets/transaction_form.dart';
import 'package:expenses_tracker/widgets/transaction_list.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class SavingsScreen extends StatefulWidget {
  final List<Transaction>? savings;
  final Function(Transaction) onAddSaving;
  final Function(Transaction) onEditSaving;
  final Function(String, TransactionType) onRemoveTransaction;
  final Future<void> Function(List<String>)? onRemoveMultiple;
  final void Function(bool)? onSelectionModeChanged;

  const SavingsScreen({
    super.key,
    required this.savings,
    required this.onAddSaving,
    required this.onEditSaving,
    required this.onRemoveTransaction,
    this.onRemoveMultiple,
    this.onSelectionModeChanged,
  });

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  bool _isSelecting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          widget.savings == null
              ? const Center(child: CircularProgressIndicator())
              : widget.savings!.isEmpty
              ? _buildEmptyState()
              : TransactionList(
                transactions: widget.savings!,
                transactionType: TransactionType.saving,
                onRemoveTransaction: widget.onRemoveTransaction,
                onEditTransaction:
                    (transaction) => _showEditSavingForm(context, transaction),
                onRemoveMultiple: widget.onRemoveMultiple,
                onSelectionModeChanged: (selecting) {
                  setState(() => _isSelecting = selecting);
                  widget.onSelectionModeChanged?.call(selecting);
                },
              ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
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
            onSave: widget.onAddSaving,
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
            onSave: widget.onEditSaving,
          ),
    );
  }
}
