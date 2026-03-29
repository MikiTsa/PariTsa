import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/screens/expenses_screen.dart';
import 'package:expenses_tracker/screens/incomes_screen.dart';
import 'package:expenses_tracker/screens/savings_screen.dart';
import 'package:expenses_tracker/widgets/balance_box.dart';
import 'package:expenses_tracker/widgets/app_drawer.dart';
import 'package:expenses_tracker/widgets/transaction_form.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/services/auth_service.dart';
import 'package:expenses_tracker/services/local_notification_service.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _tabController?.dispose();
    super.dispose();
  }

  double get currentBalance {
    double income  = (incomes  ?? []).fold(0, (sum, item) => sum + item.amount);
    double expense = (expenses ?? []).fold(0, (sum, item) => sum + item.amount);
    double saving  = (savings  ?? []).fold(0, (sum, item) => sum + item.amount);
    return income - expense - saving;
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
                              // Wallet test trigger — visible only in debug builds.
                              if (const bool.fromEnvironment('dart.vm.product') == false)
                                IconButton(
                                  onPressed: () async {
                                    const title    = 'Lidl Slovenija d o o';
                                    const amount   = 52.43;
                                    const category = 'Groceries';
                                    await addTransaction(
                                      Transaction(
                                        title: title,
                                        amount: amount,
                                        date: DateTime.now(),
                                        category: category,
                                        note: 'Auto-captured from Google Wallet',
                                      ),
                                      TransactionType.expense,
                                    );
                                    await LocalNotificationService.instance
                                        .showExpenseAdded(
                                      title: title,
                                      amount: amount,
                                      category: category,
                                    );
                                  },
                                  icon: const Icon(Icons.wallet),
                                  tooltip: 'Test wallet notification',
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
                        expenses: expenses,
                        onAddExpense: (t) =>
                            addTransaction(t, TransactionType.expense),
                        onEditExpense: (t) =>
                            editTransaction(t, TransactionType.expense),
                        onRemoveTransaction: removeTransaction,
                      ),
                      IncomesScreen(
                        incomes: incomes,
                        onAddIncome: (t) =>
                            addTransaction(t, TransactionType.income),
                        onEditIncome: (t) =>
                            editTransaction(t, TransactionType.income),
                        onRemoveTransaction: removeTransaction,
                      ),
                      SavingsScreen(
                        savings: savings,
                        onAddSaving: (t) =>
                            addTransaction(t, TransactionType.saving),
                        onEditSaving: (t) =>
                            editTransaction(t, TransactionType.saving),
                        onRemoveTransaction: removeTransaction,
                      ),

                    ],
                  ),
                ),
              ],
            ),

            // Floating balance box — AnimatedBuilder redraws on every animation
            // frame so the colour interpolates continuously during swipe/tap.
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
