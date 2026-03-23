import 'dart:async';

import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          indicatorColor: AppColors.pearlAqua,
          dividerColor: Colors.transparent,
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
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CategoryTab(type: TransactionType.expense, color: AppColors.expense),
          _CategoryTab(type: TransactionType.income, color: AppColors.income),
          _CategoryTab(type: TransactionType.saving, color: AppColors.saving),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  final TransactionType type;
  final Color color;

  const _CategoryTab({required this.type, required this.color});

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab>
    with AutomaticKeepAliveClientMixin {
  final _addController = TextEditingController();
  final _firebaseService = FirebaseService();

  List<String> _categories = [];
  bool _loading = true;
  bool _saving = false;

  // Undo state — cleared after 4 seconds or when undo is pressed
  String? _lastDeletedName;
  int? _lastDeletedIndex;
  Timer? _undoTimer;

  StreamSubscription<List<String>>? _subscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subscription = _firebaseService
        .getCategoriesStream(widget.type)
        .listen((cats) {
          if (mounted) {
            setState(() {
              _categories = cats;
              _loading = false;
            });
          }
        });
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _subscription?.cancel();
    _addController.dispose();
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<String>.from(_categories);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _categories = updated);
    _firebaseService.reorderCategories(updated, widget.type);
  }

  Future<void> _onDismissed(String name, int index) async {
    // Delete from Firestore immediately — Firestore is the source of truth
    try {
      await _firebaseService.deleteCategory(name, widget.type);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete category'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show inline undo banner for 4 seconds
    _undoTimer?.cancel();
    setState(() {
      _lastDeletedName = name;
      _lastDeletedIndex = index;
    });
    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _lastDeletedName = null;
          _lastDeletedIndex = null;
        });
      }
    });
  }

  Future<void> _undoLastDeletion() async {
    _undoTimer?.cancel();
    final name = _lastDeletedName;
    final index = _lastDeletedIndex;
    if (name == null) return;

    setState(() {
      _lastDeletedName = null;
      _lastDeletedIndex = null;
    });

    try {
      await _firebaseService.insertCategoryAt(name, widget.type, index ?? 0);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restore category'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _firebaseService.addCategory(name, widget.type);
      _addController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add category'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: widget.color));
    }

    return Column(
      children: [
        Expanded(
          child: _categories.isEmpty
              ? const Center(
                  child: Text(
                    'No categories yet.\nAdd one below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText, fontSize: 15),
                  ),
                )
              : ReorderableListView(
                  buildDefaultDragHandles: false,
                  onReorder: _onReorder,
                  proxyDecorator: (child, _, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (_, _) => Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.cardBackground,
                      child: child,
                    ),
                  ),
                  children: [
                    for (int i = 0; i < _categories.length; i++)
                      _buildCategoryTile(_categories[i], i),
                  ],
                ),
        ),

        // Inline undo banner — shown for 4 s after a deletion
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _lastDeletedName != null
              ? Container(
                  key: const ValueKey('undo'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: AppColors.primaryText,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '"$_lastDeletedName" deleted',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _undoLastDeletion,
                        style: TextButton.styleFrom(
                          foregroundColor: widget.color,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Undo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no_undo')),
        ),

        // Add category input bar
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    hintText: 'New category name...',
                    hintStyle: const TextStyle(color: AppColors.mutedText),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.color, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 6),
              _saving
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: widget.color,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: widget.color,
                        size: 34,
                      ),
                      onPressed: _addCategory,
                      tooltip: 'Add category',
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(String cat, int index) {
    return Dismissible(
      key: ValueKey(cat),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.deleteAction,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _onDismissed(cat, index),
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: ListTile(
          leading: const Icon(
            Icons.drag_handle,
            color: AppColors.mutedText,
            size: 22,
          ),
          title: Text(
            cat,
            style: const TextStyle(color: AppColors.primaryText, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
