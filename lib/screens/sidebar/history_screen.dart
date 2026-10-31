import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/balance_reset.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

/// One row in the History feed: a transaction or a reset marker.
sealed class _HistoryItem {
  DateTime get date;
}

class _HistoryEntry extends _HistoryItem {
  final Transaction transaction;
  final TransactionType type;
  _HistoryEntry(this.transaction, this.type);

  @override
  DateTime get date => transaction.date;
}

class _ResetMarker extends _HistoryItem {
  final BalanceReset reset;
  _ResetMarker(this.reset);

  @override
  DateTime get date => reset.date;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = FirebaseService();
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, StreamSubscription<dynamic>> _sharedTxSubs = {};
  final Map<String, List<Transaction>> _sharedTxData = {};
  bool _popping = false;

  List<Transaction> _expenses = [];
  List<Transaction> _incomes = [];
  List<Transaction> _savings = [];
  List<BalanceReset> _resets = [];

  @override
  void initState() {
    super.initState();
    _subs.add(
      _service.getResetsStream().listen(
        (list) {
          if (mounted && !_popping) setState(() => _resets = list);
        },
        onError: (Object e) {
          debugPrint('Resets stream error: $e');
        },
      ),
    );
    _subs.add(
      _service.getTransactionsStream(TransactionType.expense).listen((list) {
        if (mounted && !_popping) setState(() => _expenses = list);
      }),
    );
    _subs.add(
      _service.getTransactionsStream(TransactionType.income).listen((list) {
        if (mounted && !_popping) setState(() => _incomes = list);
      }),
    );
    _subs.add(
      _service.getTransactionsStream(TransactionType.saving).listen((list) {
        if (mounted && !_popping) setState(() => _savings = list);
      }),
    );
    _subs.add(
      _service.getSharedTrackersStream().listen((trackers) {
        if (!mounted || _popping) return;
        final uid = _service.currentUserId;
        if (uid == null) return;

        final currentIds = trackers.map((t) => t.id).toSet();

        for (final id
            in _sharedTxSubs.keys
                .where((k) => !currentIds.contains(k))
                .toList()) {
          _sharedTxSubs[id]?.cancel();
          _sharedTxSubs.remove(id);
          _sharedTxData.remove(id);
        }

        for (final tracker in trackers) {
          if (_sharedTxSubs.containsKey(tracker.id)) continue;
          final tid = tracker.id;
          _sharedTxSubs[tid] = _service.getSharedTransactionsStream(tid).listen(
            (txList) {
              if (!mounted || _popping) return;
              _sharedTxData[tid] =
                  txList.where((tx) => tx.splits.any((s) => s.uid == uid)).map((
                    tx,
                  ) {
                    final split = tx.splits.firstWhere((s) => s.uid == uid);
                    return Transaction(
                      id: tx.id,
                      title: tx.title,
                      amount: split.amount,
                      date: tx.date,
                      category: split.myCategory ?? tx.category,
                      note: tx.note,
                      tag: tx.tag,
                      sharedTrackerId: tid,
                    );
                  }).toList();
              setState(() {});
            },
          );
        }

        if (currentIds.isEmpty) setState(() => _sharedTxData.clear());
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final s in _sharedTxSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  List<_HistoryItem> get _sorted {
    final sharedEntries = _sharedTxData.values
        .expand((l) => l)
        .map((t) => _HistoryEntry(t, TransactionType.expense));
    return <_HistoryItem>[
      ..._expenses.map((t) => _HistoryEntry(t, TransactionType.expense)),
      ..._incomes.map((t) => _HistoryEntry(t, TransactionType.income)),
      ..._savings.map((t) => _HistoryEntry(t, TransactionType.saving)),
      ...sharedEntries,
      ..._resets.map(_ResetMarker.new),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// A full-width line with a pill: "Balance reset to €0.00" and, beneath it,
  /// what the total was before. Transactions above it count toward the total.
  Widget _buildResetMarker(BuildContext context, BalanceReset reset) {
    final settings = AppSettingsScope.of(context);
    final isBalance = reset.target == ResetTarget.balance;
    final color = isBalance ? AppColors.primary : AppColors.saving;
    final label = isBalance ? 'Balance' : 'Savings';

    final line = Expanded(
      child: Divider(color: color.withValues(alpha: 0.6), thickness: 1.5),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              line,
              // Capped so a huge amount ellipsizes instead of overflowing.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.7,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restart_alt, size: 15, color: color),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '$label reset to ${settings.formatAmountFull(reset.amount)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              line,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'was ${settings.formatAmountFull(reset.previousAmount)}'
            '  ·  ${DateFormat.jm().format(reset.date)}',
            style: TextStyle(fontSize: 11, color: context.cMutedText),
          ),
        ],
      ),
    );
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
      builder:
          (ctx) => Container(
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
                      child: Image.asset(
                        iconPath,
                        width: 28,
                        height: 28,
                        color: color,
                      ),
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
                _buildDetailRow(
                  ctx,
                  Icons.swap_horiz,
                  'Type',
                  _typeLabel(entry.type),
                ),
                if (t.category != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    ctx,
                    Icons.category_outlined,
                    'Category',
                    t.category!,
                  ),
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

  @override
  Widget build(BuildContext context) {
    final entries = _sorted;
    final settings = AppSettingsScope.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _popping = true;
      },
      child: Scaffold(
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
        body:
            entries.isEmpty
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
                    final item = entries[index];

                    final isFirstOfDay =
                        index == 0 ||
                        !DateUtils.isSameDay(
                          item.date,
                          entries[index - 1].date,
                        );

                    final dayHeader = [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          _formatDateHeader(item.date, settings),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.cSecondaryText,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Divider(color: context.cDivider, thickness: 1),
                    ];

                    if (item is _ResetMarker) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isFirstOfDay) ...dayHeader,
                          _buildResetMarker(context, item.reset),
                        ],
                      );
                    }

                    final entry = item as _HistoryEntry;
                    final t = entry.transaction;
                    final color = _colorFor(entry.type);
                    final iconPath = _iconPathFor(entry.type);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFirstOfDay) ...dayHeader,
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Image.asset(
                                iconPath,
                                width: 22,
                                height: 22,
                                color: color,
                              ),
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
                                if (t.isShared)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
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
      ),
    );
  }
}
