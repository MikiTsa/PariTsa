import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

class TransactionForm extends StatefulWidget {
  final TransactionType transactionType;
  final Function(Transaction) onSave;
  final Transaction? initialTransaction;

  const TransactionForm({
    super.key,
    required this.transactionType,
    required this.onSave,
    this.initialTransaction,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<String> _categories = [];
  List<String> _usedTags = [];

  bool get isEditing => widget.initialTransaction != null;

  Color get _typeColor {
    switch (widget.transactionType) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.saving:
        return AppColors.saving;
    }
  }

  String get _typeTitle {
    switch (widget.transactionType) {
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.income:
        return 'Income';
      case TransactionType.saving:
        return 'Saving';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      _titleController.text = widget.initialTransaction!.title;
      _amountController.text = widget.initialTransaction!.amount.toString();
      _selectedDate = widget.initialTransaction!.date;
      _selectedCategory = widget.initialTransaction!.category;
      if (widget.initialTransaction!.note != null) {
        _noteController.text = widget.initialTransaction!.note!;
      }
      if (widget.initialTransaction!.tag != null) {
        _tagController.text = widget.initialTransaction!.tag!;
      }
    }
    _loadCategories();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await FirebaseService().getUsedTags();
    if (!mounted) return;
    setState(() => _usedTags = tags);
  }

  Future<void> _loadCategories() async {
    final cats = await FirebaseService().getCategories(widget.transactionType);
    if (!mounted) return;
    setState(() {
      _categories = cats;
      // Keep current selection even if it's no longer in the list
      if (_selectedCategory != null && !cats.contains(_selectedCategory)) {
        _categories = [_selectedCategory!, ...cats];
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _showCategorySheet(BuildContext context) {
    final color = _typeColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.pearlAqua,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.cPrimaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView(
                shrinkWrap: true,
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? color : context.cPrimaryText,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: color)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _typeColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showTagDialog() {
    final tempController = TextEditingController(text: _tagController.text);
    final color = _typeColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = tempController.text.trim().toLowerCase();
          final suggestions = _usedTags
              .where((t) => query.isEmpty || t.toLowerCase().contains(query))
              .toList();

          final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
          final maxHeight = MediaQuery.of(ctx).size.height * 0.9 - viewInsets;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: viewInsets + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.pearlAqua,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tag (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.cPrimaryText,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tempController,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Vacation 2025, Side project',
                    prefixIcon: Icon(
                      Icons.label_outline,
                      color: AppColors.darkCyan,
                    ),
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestions.map((tag) {
                      final isSelected = tempController.text.trim() == tag;
                      return ActionChip(
                        label: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? color
                            : color.withValues(alpha: 0.12),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () {
                          tempController.text = tag;
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _tagController.text = '');
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(
                            () => _tagController.text = tempController.text.trim());
                        Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(foregroundColor: color),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final transactionData = Transaction(
        id: isEditing ? widget.initialTransaction!.id : null,
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        category: _selectedCategory,
        note:
            _noteController.text.isNotEmpty
                ? _noteController.text.trim()
                : null,
        tag:
            _tagController.text.isNotEmpty
                ? _tagController.text.trim()
                : null,
      );
      widget.onSave(transactionData);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.pearlAqua,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${isEditing ? 'Edit' : 'Add'} $_typeTitle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _typeColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showTagDialog,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.label_outline,
                            color:
                                _tagController.text.isNotEmpty
                                    ? _typeColor
                                    : AppColors.mutedText,
                            size: 26,
                          ),
                          if (_tagController.text.isNotEmpty)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter a title',
                    prefixIcon: Icon(Icons.title, color: AppColors.darkCyan),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Amount field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: AppColors.darkCyan,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null) {
                      return 'Please enter a valid number';
                    }
                    if (parsed <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    if (parsed > 999999999) {
                      return 'Amount is too large';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Date picker
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: AppColors.darkCyan,
                      ),
                    ),
                    child: Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: TextStyle(color: context.cPrimaryText),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category picker
                InkWell(
                  onTap: _categories.isEmpty
                      ? null
                      : () => _showCategorySheet(context),
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(
                        Icons.category_outlined,
                        color: AppColors.darkCyan,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategory ?? 'Select a category',
                          style: TextStyle(
                            color: _selectedCategory != null
                                ? context.cPrimaryText
                                : context.cMutedText,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.cMutedText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Note field
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'Add a note',
                    prefixIcon: Icon(
                      Icons.note_outlined,
                      color: AppColors.darkCyan,
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _typeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      '${isEditing ? 'Update' : 'Save'} $_typeTitle',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
