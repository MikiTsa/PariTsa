import 'dart:async';

import 'package:expenses_tracker/models/shared_tracker.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';
import 'package:expenses_tracker/widgets/shared_transaction_form.dart';
import 'package:expenses_tracker/widgets/split_bar.dart';
import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class SharedTrackerDetailScreen extends StatefulWidget {
  final String trackerId;

  const SharedTrackerDetailScreen({super.key, required this.trackerId});

  @override
  State<SharedTrackerDetailScreen> createState() =>
      _SharedTrackerDetailScreenState();
}

class _SharedTrackerDetailScreenState
    extends State<SharedTrackerDetailScreen> {
  final _service = FirebaseService();

  SharedTracker? _tracker;
  List<SharedTransaction> _transactions = [];

  StreamSubscription<SharedTracker?>? _trackerSub;
  StreamSubscription<List<SharedTransaction>>? _txSub;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _trackerSub = _service
        .getSharedTrackersStream()
        .map((list) {
          try {
            return list.firstWhere((t) => t.id == widget.trackerId);
          } catch (_) {
            return null;
          }
        })
        .listen((tracker) {
          if (!mounted) return;
          setState(() {
            _tracker = tracker;
            _loading = false;
          });
        });

    _txSub = _service
        .getSharedTransactionsStream(widget.trackerId)
        .listen((txs) {
      if (!mounted) return;
      setState(() {
        _transactions = txs..sort((a, b) => b.date.compareTo(a.date));
      });
    });
  }

  @override
  void dispose() {
    _trackerSub?.cancel();
    _txSub?.cancel();
    super.dispose();
  }

  void _showAddForm() {
    final tracker = _tracker;
    if (tracker == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharedTransactionForm(
        tracker: tracker,
        onSave: (tx) => _service.addSharedTransaction(widget.trackerId, tx),
      ),
    );
  }

  void _showEditForm(SharedTransaction tx) {
    final tracker = _tracker;
    if (tracker == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharedTransactionForm(
        tracker: tracker,
        initialTransaction: tx,
        onSave: (updated) =>
            _service.updateSharedTransaction(widget.trackerId, updated),
      ),
    );
  }

  void _confirmDeleteTransaction(SharedTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete shared expense?'),
        content: Text('Delete "${tx.title}"? This affects all members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _service.deleteSharedTransaction(widget.trackerId, tx.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.deleteAction),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(SharedTransaction tx) {
    final tracker = _tracker;
    if (tracker == null) return;
    final settings = AppSettingsScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cMutedText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title + total
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.cPrimaryText,
                    ),
                  ),
                ),
                Text(
                  settings.formatAmount(tx.totalAmount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMMd().format(tx.date),
              style: TextStyle(color: context.cSecondaryText, fontSize: 13),
            ),
            if (tx.category != null) ...[
              const SizedBox(height: 8),
              Text(tx.category!,
                  style: TextStyle(color: context.cMutedText, fontSize: 13)),
            ],
            if (tx.note != null) ...[
              const SizedBox(height: 4),
              Text(tx.note!,
                  style: TextStyle(color: context.cMutedText, fontSize: 13)),
            ],
            const SizedBox(height: 20),

            // Split bar
            SplitBar(
              totalAmount: tx.totalAmount,
              splits: tx.splits,
              members: tracker.members,
              height: 14,
            ),
            const SizedBox(height: 16),

            // Split legend
            SplitLegend(
              totalAmount: tx.totalAmount,
              splits: tx.splits,
              members: tracker.members,
              formatAmount: settings.formatAmount,
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDeleteTransaction(tx);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.deleteAction),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditForm(tx);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteCode() {
    final tracker = _tracker;
    if (tracker == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with someone to invite them to this tracker:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tracker.inviteCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: tracker.inviteCode));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLeaveOrDeleteDialog() {
    final tracker = _tracker;
    if (tracker == null) return;

    // Resolve current user uid via auth
    final uid = FirebaseService().expensesCollection?.path.split('/')[1] ?? '';
    final isCreator = tracker.createdBy == uid;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCreator ? 'Delete tracker?' : 'Leave tracker?'),
        content: Text(
          isCreator
              ? 'This will permanently delete "${tracker.name}" and all its transactions for everyone.'
              : 'You will leave "${tracker.name}" and its expenses will be removed from your balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (isCreator) {
                  await _service.deleteSharedTracker(widget.trackerId);
                } else {
                  await _service.leaveSharedTracker(widget.trackerId);
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.deleteAction),
            child: Text(isCreator ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tracker?.name ?? 'Shared Tracker'),
        backgroundColor: context.cAppBar,
        foregroundColor: context.cPrimaryText,
        elevation: 0,
        actions: [
          if (tracker != null) ...[
            IconButton(
              onPressed: _showInviteCode,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Invite code',
            ),
            IconButton(
              onPressed: _showLeaveOrDeleteDialog,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Leave / delete tracker',
              color: AppColors.deleteAction,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : tracker == null
              ? const Center(child: Text('Tracker not found'))
              : Column(
                  children: [
                    // Members row
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      color: context.cCard,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tracker.members.map((m) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor:
                                  m.color.withValues(alpha: 0.2),
                              child: Text(
                                _initials(m.displayName),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: m.color,
                                ),
                              ),
                            ),
                            label: Text(m.displayName,
                                style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),

                    const Divider(height: 1),

                    // Transactions list
                    Expanded(
                      child: _transactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 64,
                                    color: AppColors.mutedText
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No shared expenses yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: context.cSecondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap + to add one',
                                    style:
                                        TextStyle(color: context.cMutedText),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _transactions.length,
                              itemBuilder: (ctx, i) {
                                final tx = _transactions[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _showTransactionDetail(tx),
                                    onLongPress: () =>
                                        _confirmDeleteTransaction(tx),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  tx.title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: context.cPrimaryText,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                settings.formatAmount(
                                                    tx.totalAmount),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: AppColors.expense,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat.yMMMd()
                                                .format(tx.date),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.cMutedText,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SplitBar(
                                            totalAmount: tx.totalAmount,
                                            splits: tx.splits,
                                            members: tracker.members,
                                            height: 10,
                                          ),
                                          const SizedBox(height: 6),
                                          // Per-member amounts in a row
                                          Wrap(
                                            spacing: 12,
                                            children: tx.splits.map((s) {
                                              final m = tracker.memberFor(s.uid);
                                              if (m == null) {
                                                return const SizedBox.shrink();
                                              }
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: m.color,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    settings.formatAmount(
                                                        s.amount),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: m.color,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: tracker != null
          ? FloatingActionButton(
              onPressed: _showAddForm,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
