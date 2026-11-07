import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/currency.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/screens/sidebar/shared_tracker_detail_screen.dart';
import 'package:expenses_tracker/services/exchange_rate_service.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';
import 'package:expenses_tracker/widgets/currency_picker.dart';

class TransactionList extends StatefulWidget {
  final List<Transaction> transactions;
  final TransactionType transactionType;
  final Function(String, TransactionType)? onRemoveTransaction;
  final Function(Transaction)? onEditTransaction;
  final Future<void> Function(Transaction)? onMoveToShared;
  // Multi-select callbacks
  final Future<void> Function(List<String>)? onRemoveMultiple;
  final Future<void> Function(List<Transaction>)? onMoveMultipleToShared;
  // Called whenever the user enters/exits multi-select mode
  final void Function(bool)? onSelectionModeChanged;

  const TransactionList({
    super.key,
    required this.transactions,
    required this.transactionType,
    this.onRemoveTransaction,
    this.onEditTransaction,
    this.onMoveToShared,
    this.onRemoveMultiple,
    this.onMoveMultipleToShared,
    this.onSelectionModeChanged,
  });

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  final Set<String> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  Color get _typeColor {
    switch (widget.transactionType) {
      case TransactionType.expense: return AppColors.expense;
      case TransactionType.income:  return AppColors.income;
      case TransactionType.saving:  return AppColors.saving;
    }
  }

  String get _typeIconPath {
    switch (widget.transactionType) {
      case TransactionType.expense: return 'assets/expense_icon.png';
      case TransactionType.income:  return 'assets/income_icon.png';
      case TransactionType.saving:  return 'assets/saving_icon.png';
    }
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
    widget.onSelectionModeChanged?.call(false);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    if (_selectedIds.isEmpty) widget.onSelectionModeChanged?.call(false);
  }

  void _enterSelectMode(Transaction transaction) {
    setState(() => _selectedIds.add(transaction.id));
    widget.onSelectionModeChanged?.call(true);
  }

  List<Transaction> get _selectedTransactions =>
      widget.transactions.where((t) => _selectedIds.contains(t.id)).toList();

  void _handleTap(Transaction transaction, AppSettings settings) {
    if (_isSelecting) {
      if (transaction.isShared) return; // shared items not selectable
      _toggleSelection(transaction.id);
    } else {
      _showTransactionDetails(context, transaction, settings);
    }
  }

  void _handleLongPress(Transaction transaction) {
    if (transaction.isShared) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open Shared Tracking to manage shared expenses'),
        ),
      );
      return;
    }
    if (_isSelecting) {
      _toggleSelection(transaction.id);
    } else {
      _showLongPressActions(context, transaction);
    }
  }

  void _confirmDeleteSelected() {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.deleteAction, size: 28),
        title: Text('Delete $count ${count == 1 ? 'transaction' : 'transactions'}?'),
        content: Text(
          'This will permanently delete $count selected item${count == 1 ? '' : 's'}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ids = List<String>.from(_selectedIds);
              _clearSelection();
              widget.onRemoveMultiple?.call(ids);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.deleteAction,
              backgroundColor: AppColors.deleteAction.withValues(alpha: 0.08),
            ),
            child: Text('Delete $count'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveSelected() async {
    final txs = _selectedTransactions;
    _clearSelection();
    await widget.onMoveMultipleToShared?.call(txs);
  }

  /// Fix entries saved with the wrong currency: treat each selected amount
  /// as [code] and convert it at the rate of the transaction's own date.
  Future<void> _convertSelected() async {
    final base = AppSettingsScope.of(context).currency;
    final messenger = ScaffoldMessenger.of(context);
    final selected = _selectedTransactions.where((t) => !t.isShared).toList();

    final code = await showCurrencyPicker(
      context,
      current: base,
      title: 'These were paid in…',
      accent: _typeColor,
    );
    if (code == null || code == base || !mounted) return;

    final toConvert = selected.where((t) => !t.isForeign).toList();
    final skipped = selected.length - toConvert.length;
    if (toConvert.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('These transactions already have a currency'),
      ));
      return;
    }

    final n = toConvert.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Convert $n ${n == 1 ? 'transaction' : 'transactions'} from $code?'),
        content: Text(
          'Each amount is treated as $code and converted to $base at the '
          'rate of its own date. Use this for entries that were saved in '
          'the wrong currency.'
          '${skipped > 0 ? '\n\n$skipped already converted ${skipped == 1 ? 'entry is' : 'entries are'} skipped.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _typeColor),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text('Converting from $code…')),
            ],
          ),
        ),
      ),
    );

    try {
      final converted = <Transaction>[];
      for (final t in toConvert) {
        final quote = await ExchangeRateService.instance.quote(
          from: code,
          to: base,
          date: t.date,
        );
        if (quote == null) {
          throw Exception("couldn't get the $code rate. Check your connection");
        }
        converted.add(t.withForeignAmount(
          foreignAmount: t.amount,
          currency: code,
          rate: quote.rate,
          estimated: quote.estimated,
        ));
      }
      await FirebaseService().saveTransactions(
        converted,
        widget.transactionType,
      );
      navigator.pop();
      _clearSelection();
      messenger.showSnackBar(SnackBar(
        content: Text('Converted $n ${n == 1 ? 'transaction' : 'transactions'} from $code'),
      ));
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Conversion failed: $e'),
        backgroundColor: AppColors.expense,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final sortedTransactions = [...widget.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedTransactions.length,
            itemBuilder: (context, index) {
              final transaction = sortedTransactions[index];
              final isSelected = _selectedIds.contains(transaction.id);
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
                        _formatDateHeader(transaction.date, settings),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.cSecondaryText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Divider(color: context.cDivider, thickness: 1),
                  ],

                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: isSelected
                        ? _typeColor.withValues(alpha: 0.08)
                        : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _handleTap(transaction, settings),
                      onLongPress: () => _handleLongPress(transaction),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ListTile(
                          leading: _isSelecting
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: transaction.isShared
                                      ? null
                                      : (_) => _toggleSelection(transaction.id),
                                  activeColor: _typeColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor:
                                      _typeColor.withValues(alpha: 0.15),
                                  child: Image.asset(
                                    _typeIconPath,
                                    width: 22,
                                    height: 22,
                                    color: _typeColor,
                                  ),
                                ),
                          title: Text(
                            transaction.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.cPrimaryText,
                            ),
                          ),
                          subtitle: Wrap(
                            spacing: 6,
                            children: [
                              Text(
                                transaction.category ?? 'No category',
                                style: TextStyle(
                                  color: context.cSecondaryText,
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
                                    color: _typeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    transaction.tag!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _typeColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (transaction.isShared)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 11,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Shared',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (transaction.isForeign)
                                Text(
                                  formatWithCode(
                                        transaction.originalAmount!,
                                        transaction.originalCurrency!,
                                      ) +
                                      (transaction.rateEstimated
                                          ? ' · est.'
                                          : ''),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.cMutedText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                settings.formatAmount(transaction.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _typeColor,
                                ),
                              ),
                              Text(
                                DateFormat.jm().format(transaction.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.cMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Multi-select action bar — slides in when items are selected
        if (_isSelecting) _buildActionBar(context),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final count = _selectedIds.length;
    final canMove =
        widget.transactionType == TransactionType.expense &&
        widget.onMoveMultipleToShared != null;

    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        border: Border(
          top: BorderSide(color: context.cDivider, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel + count
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.close, size: 18),
              label: Text(
                '$count selected',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.cPrimaryText,
              ),
            ),
            const Spacer(),
            // Convert from another currency (fixes wrongly saved amounts)
            IconButton(
              onPressed: _convertSelected,
              tooltip: 'Convert from another currency',
              icon: const Icon(Icons.currency_exchange, size: 20),
              color: _typeColor,
            ),
            // Move to Shared (expenses only)
            if (canMove) ...[
              TextButton.icon(
                onPressed: _moveSelected,
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Move'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Delete
            FilledButton.icon(
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deleteAction,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date, AppSettings settings) {
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
    }
    return settings.formatDate(date);
  }

  void _showLongPressActions(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        child: SafeArea(
          top: false,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cMutedText.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            // Select multiple
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: Icon(Icons.check_circle_outline,
                  color: context.cSecondaryText),
              title: Text(
                'Select',
                style: TextStyle(
                  color: context.cPrimaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _enterSelectMode(transaction);
              },
            ),
            if (widget.onMoveToShared != null &&
                widget.transactionType == TransactionType.expense)
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.people_outline, color: AppColors.primary),
                title: Text(
                  'Move to Shared Tracker',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onMoveToShared!(transaction);
                },
              ),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.deleteAction),
              title: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.deleteAction,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteSingle(context, transaction);
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _confirmDeleteSingle(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline,
            color: AppColors.deleteAction, size: 28),
        title: const Text('Delete transaction?'),
        content:
            Text('Are you sure you want to delete "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onRemoveTransaction
                  ?.call(transaction.id, widget.transactionType);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.deleteAction,
              backgroundColor: AppColors.deleteAction.withValues(alpha: 0.08),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    Transaction transaction,
    AppSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cMutedText.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _typeColor.withValues(alpha: 0.15),
                  radius: 24,
                  child: Image.asset(
                    _typeIconPath,
                    width: 28,
                    height: 28,
                    color: _typeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.cPrimaryText,
                        ),
                      ),
                      Text(
                        settings.formatDateWithTime(transaction.date),
                        style: TextStyle(
                          color: context.cSecondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  settings.formatAmount(transaction.amount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _typeColor,
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
                          context,
                          Icons.category_outlined,
                          'Category',
                          transaction.category!,
                        ),
                        if (transaction.note != null)
                          const SizedBox(height: 12),
                      ],
                      if (transaction.note != null)
                        _buildDetailRow(
                          context,
                          Icons.note_outlined,
                          'Note',
                          transaction.note!,
                        ),
                      if (transaction.tag != null) ...[
                        if (transaction.category != null ||
                            transaction.note != null)
                          const SizedBox(height: 12),
                        _buildDetailRow(
                          context,
                          Icons.label_outline,
                          'Tag',
                          transaction.tag!,
                        ),
                      ],
                      if (transaction.isForeign) ...[
                        if (transaction.category != null ||
                            transaction.note != null ||
                            transaction.tag != null)
                          const SizedBox(height: 12),
                        _buildDetailRow(
                          context,
                          Icons.currency_exchange,
                          'Paid in ${transaction.originalCurrency}',
                          originalAmountDetail(transaction, settings.currency),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (transaction.isShared)
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SharedTrackerDetailScreen(
                            trackerId: transaction.sharedTrackerId!,
                          ),
                        ),
                      );
                    },
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    tooltip: 'Open in Shared Tracking',
                    child: const Icon(Icons.people_outline),
                  )
                else
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onEditTransaction?.call(transaction);
                    },
                    backgroundColor: _typeColor,
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

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
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
                style: TextStyle(fontSize: 12, color: context.cMutedText),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 16, color: context.cPrimaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
