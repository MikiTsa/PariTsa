import 'dart:async';

import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/screens/expenses_screen.dart';
import 'package:expenses_tracker/screens/incomes_screen.dart';
import 'package:expenses_tracker/screens/savings_screen.dart';
import 'package:expenses_tracker/widgets/balance_box.dart';
import 'package:expenses_tracker/widgets/app_drawer.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/services/auth_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<Transaction> expenses = [];
  List<Transaction> incomes = [];
  List<Transaction> savings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Listen to Firebase streams
    _setupFirebaseListeners();
  }

  // Setup real-time listeners for all transaction types
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
    _tabController.dispose();
    super.dispose();
  }

  // Calculate current balance based on incomes, expenses, and savings
  double get currentBalance {
    double income = incomes.fold(0, (sum, item) => sum + item.amount);
    double expense = expenses.fold(0, (sum, item) => sum + item.amount);
    double saving = savings.fold(0, (sum, item) => sum + item.amount);
    return income - expense - saving;
  }

  // Calculate total savings
  double get totalSavings {
    return savings.fold(0, (sum, item) => sum + item.amount);
  }

  // Add transaction to Firebase
  Future<void> addTransaction(
    Transaction transaction,
    TransactionType type,
  ) async {
    try {
      await _firebaseService.addTransaction(transaction, type);
      // No need to call setState - the stream listener will update automatically
    } catch (e) {
      _showErrorSnackBar('Failed to add transaction');
    }
  }

  // Edit transaction in Firebase
  Future<void> editTransaction(
    Transaction updatedTransaction,
    TransactionType type,
  ) async {
    try {
      await _firebaseService.updateTransaction(updatedTransaction, type);
      // No need to call setState - the stream listener will update automatically
    } catch (e) {
      _showErrorSnackBar('Failed to update transaction');
    }
  }

  // Remove transaction from Firebase
  Future<void> removeTransaction(String id, TransactionType type) async {
    try {
      await _firebaseService.deleteTransaction(id, type);
      // No need to call setState - the stream listener will update automatically
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

  // 🔥 NEW: Logout function
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Custom App Bar with title and tab bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.appBar,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
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
                            color: AppColors.primaryText,
                          ),
                          const Text(
                            'PariTsa',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.appBarText,
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
                                controller: _tabController,
                                indicatorWeight: 3,
                                indicatorColor: AppColors.pearlAqua,
                                dividerColor: Colors.transparent,
                                labelColor: AppColors.appBarText,
                                unselectedLabelColor: AppColors.mutedText,
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
                    controller: _tabController,
                    children: [
                      // Expenses Tab
                      ExpensesScreen(
                        expenses: expenses,
                        onAddExpense:
                            (transaction) => addTransaction(
                              transaction,
                              TransactionType.expense,
                            ),
                        onEditExpense:
                            (transaction) => editTransaction(
                              transaction,
                              TransactionType.expense,
                            ),
                        onRemoveTransaction: removeTransaction,
                      ),

                      // Incomes Tab
                      IncomesScreen(
                        incomes: incomes,
                        onAddIncome:
                            (transaction) => addTransaction(
                              transaction,
                              TransactionType.income,
                            ),
                        onEditIncome:
                            (transaction) => editTransaction(
                              transaction,
                              TransactionType.income,
                            ),
                        onRemoveTransaction: removeTransaction,
                      ),

                      // Savings Tab
                      SavingsScreen(
                        savings: savings,
                        onAddSaving:
                            (transaction) => addTransaction(
                              transaction,
                              TransactionType.saving,
                            ),
                        onEditSaving:
                            (transaction) => editTransaction(
                              transaction,
                              TransactionType.saving,
                            ),
                        onRemoveTransaction: removeTransaction,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Floating balance box - positioned on the left side
            Positioned(
              left: 16,
              bottom: 20,
              child: BalanceBox(
                amount:
                    _tabController.index == 2 ? totalSavings : currentBalance,
                isSavings: _tabController.index == 2,
                activeTabIndex: _tabController.index,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

