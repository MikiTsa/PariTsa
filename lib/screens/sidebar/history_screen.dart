import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

class _HistoryEntry {
  final Transaction transaction;
  final TransactionType type;
  _HistoryEntry(this.transaction, this.type);
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = FirebaseService();
  final List<StreamSubscription<dynamic>> _subs = [];

  List<Transaction> _expenses = [];
  List<Transaction> _incomes = [];
  List<Transaction> _savings = [];

  @override
  void initState() {
    super.initState();
    _subs.add(
      _service.getTransactionsStream(TransactionType.expense).listen((list) {
        if (mounted) setState(() => _expenses = list);
      }),
    );
    _subs.add(
      _service.getTransactionsStream(TransactionType.income).listen((list) {
        if (mounted) setState(() => _incomes = list);
      }),
    );
    _subs.add(
      _service.getTransactionsStream(TransactionType.saving).listen((list) {
        if (mounted) setState(() => _savings = list);
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<_HistoryEntry> get _sorted {
    return [
      ..._expenses.map((t) => _HistoryEntry(t, TransactionType.expense)),
      ..._incomes.map((t) => _HistoryEntry(t, TransactionType.income)),
      ..._savings.map((t) => _HistoryEntry(t, TransactionType.saving)),
    ]..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
  }

  Color _colorFor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.saving:
        return AppColors.saving;
    }
  }

  String _iconPathFor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'assets/expense_icon.png';
      case TransactionType.income:
        return 'assets/income_icon.png';
      case TransactionType.saving:
        return 'assets/saving_icon.png';
    }
  }

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.income:
        return 'Income';
      case TransactionType.saving:
        return 'Saving';
    }
  }

  String _formatDateHeader(DateTime date, AppSettings settings) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(date, DateTime(now.year, now.month, now.day - 1))) {
      return 'Yesterday';
    }
    if (date.isAfter(DateTime(now.year, now.month, now.day - 7))) {
      return DateFormat.EEEE().format(date);
    }
    return settings.formatDate(date);
  }

  void _showDetails(BuildContext context, _HistoryEntry entry) {
    final t = entry.transaction;
    final color = _colorFor(entry.type);
    final iconPath = _iconPathFor(entry.type);
    final settings = AppSettingsScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.cCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.cMutedText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  radius: 24,
                  child: Image.asset(iconPath, width: 28, height: 28, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ctx.cPrimaryText,
                        ),
                      ),
                      Text(
                        settings.formatDateWithTime(t.date),
                        style: TextStyle(
                          color: ctx.cSecondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  settings.formatAmount(t.amount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(ctx, Icons.swap_horiz, 'Type', _typeLabel(entry.type)),
            if (t.category != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(ctx, Icons.category_outlined, 'Category', t.category!),
            ],
            if (t.note != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(ctx, Icons.note_outlined, 'Note', t.note!),
            ],
            if (t.tag != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(ctx, Icons.label_outline, 'Tag', t.tag!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
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

  @override
  Widget build(BuildContext context) {
    final entries = _sorted;
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cAppBar,
        foregroundColor: context.cPrimaryText,
        elevation: 0,
        title: Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.cPrimaryText,
          ),
        ),
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: context.cMutedText),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: context.cMutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final t = entry.transaction;
                final color = _colorFor(entry.type);
                final iconPath = _iconPathFor(entry.type);

                final isFirstOfDay =
                    index == 0 ||
                    !DateUtils.isSameDay(
                      t.date,
                      entries[index - 1].transaction.date,
                    );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFirstOfDay) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          _formatDateHeader(t.date, settings),
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
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Image.asset(iconPath, width: 22, height: 22, color: color),
                        ),
                        title: Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.cPrimaryText,
                          ),
                        ),
                        subtitle: Wrap(
                          spacing: 6,
                          children: [
                            Text(
                              t.category ?? 'No category',
                              style: TextStyle(
                                color: context.cSecondaryText,
                                fontSize: 12,
                              ),
                            ),
                            if (t.tag != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t.tag!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
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
                              settings.formatAmount(t.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                            Text(
                              DateFormat.jm().format(t.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.cMutedText,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showDetails(context, entry),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
