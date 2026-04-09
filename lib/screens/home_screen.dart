import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';
import 'package:expenses_tracker/models/shared_tracker.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/screens/expenses_screen.dart';
import 'package:expenses_tracker/screens/incomes_screen.dart';
import 'package:expenses_tracker/screens/savings_screen.dart';
import 'package:expenses_tracker/widgets/balance_box.dart';
import 'package:expenses_tracker/widgets/app_drawer.dart';
import 'package:expenses_tracker/widgets/shared_transaction_form.dart';
import 'package:expenses_tracker/widgets/transaction_form.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/services/auth_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _widgetChannel = MethodChannel('com.example.expenses_tracker/widget');

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  TabController? _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;

  List<Transaction>? expenses;
  List<Transaction>? incomes;
  List<Transaction>? savings;
  List<Transaction>? sharedExpenses;
  List<SharedTracker> _sharedTrackers = [];
  bool _isSelectingInList = false;

  // Nested subscriptions for shared expenses — one per shared tracker
  final Map<String, StreamSubscription<dynamic>> _sharedTxSubs = {};
  final Map<String, List<Transaction>> _sharedTxData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFirebaseListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final defaultTab = AppSettingsScope.of(context).defaultTab;
      _tabController = TabController(
        length: 3,
        vsync: this,
        initialIndex: defaultTab,
      );
      // No listener needed — AnimatedBuilder on tabCtrl.animation handles BalanceBox redraws.

      // Cold-launch path: app was started by tapping a widget.
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkWidgetAction());
    }
  }

  Future<void> _checkWidgetAction() async {
    try {
      final action = await _widgetChannel.invokeMethod<String?>('checkLaunchAction');
      if (action != null && mounted) _openTransactionForm(action);
    } catch (e) {
      debugPrint('Widget checkLaunchAction failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Warm-resume path: Kotlin stores the action in pendingWidgetAction before
    // onResume fires, so checkLaunchAction always finds it here.
    if (state == AppLifecycleState.resumed) _checkWidgetAction();
  }

  void _openTransactionForm(String action) {
    // Wallet notification tap: just show the expenses tab, no form.
    if (action == 'open_expenses') {
      _tabController?.animateTo(0);
      return;
    }

    final int tabIndex;
    final TransactionType type;
    switch (action) {
      case 'add_income':
        tabIndex = 1;
        type = TransactionType.income;
      case 'add_saving':
        tabIndex = 2;
        type = TransactionType.saving;
      default:
        tabIndex = 0;
        type = TransactionType.expense;
    }
    _tabController?.animateTo(tabIndex);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionForm(
        transactionType: type,
        onSave: (t) => addTransaction(t, type),
      ),
    );
  }

  void _setupFirebaseListeners() {
    _subscriptions.add(
      _firebaseService.getTransactionsStream(TransactionType.expense).listen((
        transactions,
      ) {
        if (mounted) setState(() => expenses = transactions);
      }),
    );

    _subscriptions.add(
      _firebaseService.getTransactionsStream(TransactionType.income).listen((
        transactions,
      ) {
        if (mounted) setState(() => incomes = transactions);
      }),
    );

    _subscriptions.add(
      _firebaseService.getTransactionsStream(TransactionType.saving).listen((
        transactions,
      ) {
        if (mounted) setState(() => savings = transactions);
      }),
    );

    // Subscribe to the tracker list, then maintain one tx-subscription per tracker
    _subscriptions.add(
      _firebaseService.getSharedTrackersStream().listen((trackers) {
        if (!mounted) return;
        final uid = _firebaseService.currentUserId;
        if (uid == null) return;

        setState(() => _sharedTrackers = trackers);

        final currentIds = trackers.map((t) => t.id).toSet();

        // Cancel subs for trackers the user left
        for (final id in _sharedTxSubs.keys
            .where((k) => !currentIds.contains(k))
            .toList()) {
          _sharedTxSubs[id]?.cancel();
          _sharedTxSubs.remove(id);
          _sharedTxData.remove(id);
        }

        // Start subs for newly joined trackers
        for (final tracker in trackers) {
          if (_sharedTxSubs.containsKey(tracker.id)) continue;
          final tid = tracker.id;
          _sharedTxSubs[tid] = _firebaseService
              .getSharedTransactionsStream(tid)
              .listen((txList) {
            if (!mounted) return;
            _sharedTxData[tid] = txList
                .where((tx) => tx.splits.any((s) => s.uid == uid))
                .map((tx) {
                  final split =
                      tx.splits.firstWhere((s) => s.uid == uid);
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
                })
                .toList();
            setState(() {
              sharedExpenses =
                  _sharedTxData.values.expand((l) => l).toList();
            });
          }, onError: (Object e) {
            debugPrint('Shared tx stream error (tracker $tid): $e');
          });
        }

        // If user has no trackers, clear immediately
        if (currentIds.isEmpty) {
          setState(() => sharedExpenses = []);
        }
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final sub in _sharedTxSubs.values) {
      sub.cancel();
    }
    _tabController?.dispose();
    super.dispose();
  }

  double get currentBalance {
    double income  = (incomes  ?? []).fold(0, (sum, item) => sum + item.amount);
    double expense = (expenses ?? []).fold(0, (sum, item) => sum + item.amount);
    double shared  = (sharedExpenses ?? []).fold(0, (sum, item) => sum + item.amount);
    double saving  = (savings  ?? []).fold(0, (sum, item) => sum + item.amount);
    return income - expense - shared - saving;
  }

  double get totalSavings {
    return (savings ?? []).fold(0, (sum, item) => sum + item.amount);
  }

  Color _interpolateTabColor(double value) {
    const colors = [
      AppColors.balanceExpense,
      AppColors.balanceIncome,
      AppColors.balanceSaving,
    ];
    final clamped = value.clamp(0.0, 2.0);
    if (clamped <= 0) return colors[0];
    if (clamped >= 2) return colors[2];
    final lower = clamped.floor().clamp(0, 1);
    return Color.lerp(colors[lower], colors[lower + 1], clamped - lower)!;
  }

  Future<void> addTransaction(
    Transaction transaction,
    TransactionType type,
  ) async {
    try {
      await _firebaseService.addTransaction(transaction, type);
    } catch (e) {
      _showErrorSnackBar('Failed to add transaction');
    }
  }

  Future<void> editTransaction(
    Transaction updatedTransaction,
    TransactionType type,
  ) async {
    try {
      await _firebaseService.updateTransaction(updatedTransaction, type);
    } catch (e) {
      _showErrorSnackBar('Failed to update transaction');
    }
  }

  Future<void> removeTransaction(String id, TransactionType type) async {
    // Shared expenses are managed in Shared Tracking, not deletable here
    final isShared = sharedExpenses?.any((e) => e.id == id) ?? false;
    if (isShared) {
      _showErrorSnackBar('Open Shared Tracking to manage shared expenses');
      return;
    }
    try {
      await _firebaseService.deleteTransaction(id, type);
    } catch (e) {
      _showErrorSnackBar('Failed to delete transaction');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.expense),
    );
  }

  Future<void> _removeMultipleTransactions(
    List<String> ids,
    TransactionType type,
  ) async {
    // Filter out shared expenses — they can't be deleted from the personal list
    final sharedIds = (sharedExpenses ?? []).map((e) => e.id).toSet();
    final deletable = ids.where((id) => !sharedIds.contains(id)).toList();
    if (deletable.isEmpty) {
      _showErrorSnackBar('Shared expenses cannot be deleted from here');
      return;
    }
    try {
      await _firebaseService.deleteTransactions(deletable, type);
    } catch (e) {
      _showErrorSnackBar('Failed to delete transactions');
    }
  }

  Future<void> _handleMoveMultipleToShared(List<Transaction> expenses) async {
    // Strip out shared expenses — they're already in a shared tracker
    final personal = expenses
        .where((e) => e.sharedTrackerId == null)
        .toList();
    if (personal.isEmpty) {
      _showErrorSnackBar('All selected expenses are already shared');
      return;
    }
    if (_sharedTrackers.isEmpty) {
      _showErrorSnackBar('Join or create a shared tracker first');
      return;
    }

    final SharedTracker tracker;
    if (_sharedTrackers.length == 1) {
      tracker = _sharedTrackers.first;
    } else {
      final picked = await _showTrackerPicker();
      if (picked == null) return;
      tracker = picked;
    }
    if (!mounted) return;

    try {
      await _firebaseService.moveExpensesToSharedTracker(tracker.id, personal);
    } catch (e) {
      _showErrorSnackBar('Failed to move expenses to shared tracker');
    }
  }

  Future<void> _handleMoveToShared(Transaction expense) async {
    if (_sharedTrackers.isEmpty) {
      _showErrorSnackBar('Join or create a shared tracker first');
      return;
    }

    final SharedTracker tracker;
    if (_sharedTrackers.length == 1) {
      tracker = _sharedTrackers.first;
    } else {
      final picked = await _showTrackerPicker();
      if (picked == null) return;
      tracker = picked;
    }

    if (!mounted) return;

    final uid = _firebaseService.currentUserId ?? '';
    final member = tracker.memberFor(uid);

    final preFilled = SharedTransaction(
      title: expense.title,
      totalAmount: expense.amount,
      date: expense.date,
      category: expense.category,
      note: expense.note,
      tag: expense.tag,
      splits: member != null
          ? [Split(uid: member.uid, displayName: member.displayName, amount: expense.amount)]
          : [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharedTransactionForm(
        tracker: tracker,
        initialTransaction: preFilled,
        onSave: (tx) => _firebaseService.moveExpenseToSharedTracker(
          tracker.id, tx, expense.id,
        ),
      ),
    );
  }

  Future<SharedTracker?> _showTrackerPicker() {
    return showModalBottomSheet<SharedTracker>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.cCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
            Text(
              'Move to which tracker?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ctx.cPrimaryText,
              ),
            ),
            const SizedBox(height: 12),
            ..._sharedTrackers.map((t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.people_outline, color: AppColors.primary, size: 20),
              ),
              title: Text(t.name, style: TextStyle(color: ctx.cPrimaryText, fontWeight: FontWeight.w500)),
              subtitle: Text(
                t.members.map((m) => m.displayName).join(', '),
                style: TextStyle(fontSize: 12, color: ctx.cMutedText),
              ),
              onTap: () => Navigator.pop(ctx, t),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await _authService.signOut();
      } catch (e) {
        _showErrorSnackBar('Failed to logout');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabCtrl = _tabController;
    if (tabCtrl == null) return const SizedBox.shrink();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Custom App Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.cAppBar,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            icon: const Icon(Icons.menu),
                            tooltip: 'Menu',
                            color: context.cPrimaryText,
                          ),
                          Text(
                            'PariTsa',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.cPrimaryText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Wallet pipeline test — debug builds only.
                              // Posts a real notification from this app; the
                              // WalletNotificationService intercepts it and writes
                              // the expense to Firestore exactly as a real Google
                              // Wallet payment would. If the expense does NOT appear
                              // the service is not running (fix: enable Autostart on
                              // Xiaomi, or check notification-listener permission).
                              if (const bool.fromEnvironment('dart.vm.product') == false)
                                IconButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await const MethodChannel(
                                        'com.example.expenses_tracker/wallet_permission',
                                      ).invokeMethod<void>('testWalletNotification');
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Test notification posted — expense should appear automatically if the service is running',
                                          ),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    } catch (e) {
                                      debugPrint('testWalletNotification: $e');
                                    }
                                  },
                                  icon: const Icon(Icons.wallet),
                                  tooltip: 'Test wallet pipeline (full Kotlin path)',
                                  color: AppColors.income,
                                ),
                              IconButton(
                                onPressed: _handleLogout,
                                icon: const Icon(Icons.logout),
                                tooltip: 'Logout',
                                color: AppColors.expense,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final third = constraints.maxWidth / 3;
                          return Stack(
                            children: [
                              TabBar(
                                controller: tabCtrl,
                                indicatorWeight: 3,
                                indicatorColor: AppColors.pearlAqua,
                                dividerColor: Colors.transparent,
                                labelColor: context.cPrimaryText,
                                unselectedLabelColor: context.cMutedText,
                                tabs: const [
                                  Tab(
                                    child: Text(
                                      'Expenses',
                                      style: TextStyle(
                                        color: AppColors.expense,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Tab(
                                    child: Text(
                                      'Incomes',
                                      style: TextStyle(
                                        color: AppColors.income,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Tab(
                                    child: Text(
                                      'Savings',
                                      style: TextStyle(
                                        color: AppColors.saving,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                left: third,
                                top: 12,
                                bottom: 14,
                                child: Container(
                                  width: 1,
                                  color: AppColors.pearlAqua.withValues(alpha: 0.35),
                                ),
                              ),
                              Positioned(
                                left: third * 2,
                                top: 12,
                                bottom: 14,
                                child: Container(
                                  width: 1,
                                  color: AppColors.pearlAqua.withValues(alpha: 0.35),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: tabCtrl,
                    physics: const _EasySwipeTabPhysics(),
                    children: [
                      ExpensesScreen(
                        expenses: expenses == null && sharedExpenses == null
                            ? null
                            : [
                                ...(expenses ?? []),
                                ...(sharedExpenses ?? []),
                              ],
                        onAddExpense: (t) =>
                            addTransaction(t, TransactionType.expense),
                        onEditExpense: (t) =>
                            editTransaction(t, TransactionType.expense),
                        onRemoveTransaction: removeTransaction,
                        onMoveToShared: _handleMoveToShared,
                        onRemoveMultiple: (ids) => _removeMultipleTransactions(
                          ids, TransactionType.expense,
                        ),
                        onMoveMultipleToShared: _handleMoveMultipleToShared,
                        onSelectionModeChanged: (v) =>
                            setState(() => _isSelectingInList = v),
                      ),
                      IncomesScreen(
                        incomes: incomes,
                        onAddIncome: (t) =>
                            addTransaction(t, TransactionType.income),
                        onEditIncome: (t) =>
                            editTransaction(t, TransactionType.income),
                        onRemoveTransaction: removeTransaction,
                        onRemoveMultiple: (ids) => _removeMultipleTransactions(
                          ids, TransactionType.income,
                        ),
                        onSelectionModeChanged: (v) =>
                            setState(() => _isSelectingInList = v),
                      ),
                      SavingsScreen(
                        savings: savings,
                        onAddSaving: (t) =>
                            addTransaction(t, TransactionType.saving),
                        onEditSaving: (t) =>
                            editTransaction(t, TransactionType.saving),
                        onRemoveTransaction: removeTransaction,
                        onRemoveMultiple: (ids) => _removeMultipleTransactions(
                          ids, TransactionType.saving,
                        ),
                        onSelectionModeChanged: (v) =>
                            setState(() => _isSelectingInList = v),
                      ),

                    ],
                  ),
                ),
              ],
            ),

            // Floating balance box — hidden during multi-select to avoid
            // overlapping the action bar. AnimatedBuilder redraws on every
            // animation frame so the colour interpolates during swipe/tap.
            if (!_isSelectingInList)
              Positioned(
                left: 16,
                bottom: 20,
                child: AnimatedBuilder(
                  animation: tabCtrl.animation!,
                  builder: (context, _) {
                    final animIdx = tabCtrl.animation!.value.round().clamp(0, 2);
                    return BalanceBox(
                      amount: animIdx == 2 ? totalSavings : currentBalance,
                      isSavings: animIdx == 2,
                      baseColor: _interpolateTabColor(tabCtrl.animation!.value),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [PageScrollPhysics] that lowers the drag threshold needed to commit a tab
/// switch from the default 50 % to ~30 %.
///
/// A fast fling (≥ 300 px/s) always commits at any drag position, identical to
/// Flutter's default behaviour.  A slow swipe or deliberate drag only needs
/// ~30 % of the tab width before the page snaps over.
class _EasySwipeTabPhysics extends PageScrollPhysics {
  const _EasySwipeTabPhysics({super.parent});

  // Velocity above which we treat the gesture as a full fling and always commit.
  static const double _kFlingVelocity = 300.0;

  // Bias applied when rounding the page position:
  //   roundToDouble(page ± bias) = next/prev page when |drag| >= (0.5 - bias)
  // Fast fling: bias 0.5 → always commits regardless of drag distance.
  // Slow swipe: bias 0.2 → commits once drag ≥ 30 % of the tab width.
  static const double _kFastBias = 0.5;
  static const double _kSlowBias = 0.2;

  @override
  _EasySwipeTabPhysics applyTo(ScrollPhysics? ancestor) {
    return _EasySwipeTabPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // At the boundary, fall back to the parent physics (ClampingScrollPhysics).
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final double page = position.pixels / position.viewportDimension;

    final double targetPage;
    if (velocity > _kFlingVelocity) {
      targetPage = (page + _kFastBias).roundToDouble();
    } else if (velocity < -_kFlingVelocity) {
      targetPage = (page - _kFastBias).roundToDouble();
    } else if (velocity > tolerance.velocity) {
      targetPage = (page + _kSlowBias).roundToDouble();
    } else if (velocity < -tolerance.velocity) {
      targetPage = (page - _kSlowBias).roundToDouble();
    } else {
      targetPage = page.roundToDouble();
    }

    final double targetPixels = (targetPage * position.viewportDimension)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if (targetPixels == position.pixels) return null;
    return ScrollSpringSimulation(
      spring, position.pixels, targetPixels, velocity,
      tolerance: tolerance,
    );
  }
}
