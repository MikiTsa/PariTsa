import 'dart:async';

import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/screens/expenses_screen.dart';
import 'package:expenses_tracker/screens/incomes_screen.dart';
import 'package:expenses_tracker/screens/savings_screen.dart';
import 'package:expenses_tracker/widgets/balance_box.dart';
import 'package:expenses_tracker/widgets/app_drawer.dart';
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
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  TabController? _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;

  List<Transaction> expenses = [];
  List<Transaction> incomes = [];
  List<Transaction> savings = [];

  @override
  void initState() {
    super.initState();
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
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {});
        }
      });
    }
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
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _tabController?.dispose();
    super.dispose();
  }

  double get currentBalance {
    double income  = incomes.fold(0, (sum, item) => sum + item.amount);
    double expense = expenses.fold(0, (sum, item) => sum + item.amount);
    double saving  = savings.fold(0, (sum, item) => sum + item.amount);
    return income - expense - saving;
  }

  double get totalSavings {
    return savings.fold(0, (sum, item) => sum + item.amount);
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
                          IconButton(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout),
                            tooltip: 'Logout',
                            color: AppColors.expense,
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

            // Floating balance box
            Positioned(
              left: 16,
              bottom: 20,
              child: BalanceBox(
                amount: tabCtrl.index == 2 ? totalSavings : currentBalance,
                isSavings: tabCtrl.index == 2,
                activeTabIndex: tabCtrl.index,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
