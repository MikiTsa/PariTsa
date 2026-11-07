import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/currency.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/exchange_rate_service.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';
import 'package:expenses_tracker/widgets/currency_picker.dart';

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

  // Currency the amount is typed in; converted to the default on save.
  String _baseCurrency = 'EUR';
  String? _currency;
  RateQuote? _quote;
  bool _quoteLoading = false;
  bool _quoteFailed = false;
  int _quoteRequest = 0;
  bool _saving = false;

  bool get isEditing => widget.initialTransaction != null;
  bool get _isForeign => _currency != null && _currency != _baseCurrency;

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
      final initial = widget.initialTransaction!;
      _titleController.text = initial.title;
      // A foreign payment is edited in the currency it was paid in.
      _amountController.text =
          (initial.isForeign ? initial.originalAmount! : initial.amount)
              .toString();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currency != null) return; // first run only
    _baseCurrency = AppSettingsScope.of(context).currency;
    final initial = widget.initialTransaction;
    _currency = (initial != null && initial.isForeign)
        ? initial.originalCurrency!
        : _baseCurrency;
    if (_isForeign) {
      _quoteLoading = true;
      Future.microtask(_refreshQuote); // setState isn't allowed mid-build
    }
  }

  /// Fetches the rate for the chosen currency and date. Older in-flight
  /// requests are ignored if the user changes currency or date meanwhile.
  Future<void> _refreshQuote() async {
    if (!mounted) return;
    final request = ++_quoteRequest;
    if (!_isForeign) {
      setState(() {
        _quote = null;
        _quoteLoading = false;
        _quoteFailed = false;
      });
      return;
    }
    setState(() {
      _quote = null;
      _quoteLoading = true;
      _quoteFailed = false;
    });
    final q = await ExchangeRateService.instance.quote(
      from: _currency!,
      to: _baseCurrency,
      date: _selectedDate,
    );
    if (!mounted || request != _quoteRequest) return;
    setState(() {
      _quote = q;
      _quoteLoading = false;
      _quoteFailed = q == null;
    });
  }

  Future<void> _pickCurrency() async {
    final code = await showCurrencyPicker(
      context,
      current: _currency ?? _baseCurrency,
      accent: _typeColor,
    );
    if (code == null || code == _currency || !mounted) return;
    setState(() => _currency = code);
    _refreshQuote();
  }

  double? get _enteredAmount => double.tryParse(_amountController.text.trim());

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
    if (picked != null) {
      // The picker returns midnight; keep the time of day so an entry made
      // "today" still sorts (and counts toward a reset) after earlier ones.
      setState(() => _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _selectedDate.hour,
            _selectedDate.minute,
            _selectedDate.second,
          ));
      // A foreign amount converts at the rate of the transaction's own date.
      if (_isForeign) _refreshQuote();
    }
  }

  void _showTagDialog() {
    final tempController = TextEditingController(text: _tagController.text);
    final color = _typeColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = tempController.text.trim().toLowerCase();
          final suggestions = _usedTags
              .where((t) => query.isEmpty || t.toLowerCase().contains(query))
              .toList();

          return AlertDialog(
            scrollable: true,
            title: const Text('Tag (Optional)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: tempController,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Vacation 2025, Side project',
                    prefixIcon: Icon(Icons.label_outline, color: AppColors.darkCyan),
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
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _tagController.text = '');
                  Navigator.pop(ctx);
                },
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _tagController.text = tempController.text.trim());
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: color),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final entered = double.parse(_amountController.text.trim());
    var transactionData = Transaction(
      id: isEditing ? widget.initialTransaction!.id : null,
      title: _titleController.text.trim(),
      amount: entered,
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

    if (_isForeign) {
      // Editing without touching amount, currency or date keeps the stored
      // rate, so an unrelated edit (e.g. the title) never changes the amount.
      final initial = widget.initialTransaction;
      final rateUnchanged = initial != null &&
          initial.isForeign &&
          initial.exchangeRate != null &&
          initial.originalCurrency == _currency &&
          initial.originalAmount == entered &&
          DateUtils.isSameDay(initial.date, _selectedDate);

      RateQuote? quote;
      if (rateUnchanged) {
        quote = RateQuote(
          initial.exchangeRate!,
          estimated: initial.rateEstimated,
        );
      } else {
        quote = _quote;
        if (quote == null) {
          setState(() => _saving = true);
          quote = await ExchangeRateService.instance.quote(
            from: _currency!,
            to: _baseCurrency,
            date: _selectedDate,
          );
          if (!mounted) return;
          setState(() => _saving = false);
        }
      }

      if (quote == null) {
        setState(() => _quoteFailed = true);
        return;
      }

      transactionData = transactionData.withForeignAmount(
        foreignAmount: entered,
        currency: _currency!,
        rate: quote.rate,
        estimated: quote.estimated,
      );
      if (transactionData.amount > 999999999) {
        setState(() => _quoteFailed = true);
        return;
      }
    }

    widget.onSave(transactionData);
    if (mounted) Navigator.pop(context);
  }

  Widget _buildCurrencyChip() {
    final color = _typeColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: _pickCurrency,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _isForeign ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currency ?? _baseCurrency,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// "≈ €89.90 · 1 EUR = 61.40 MKD" under the amount when paying in another
  /// currency.
  Widget _buildConversionPreview(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final TextStyle muted = TextStyle(fontSize: 12, color: context.cMutedText);

    if (_quoteLoading) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Getting the $_currency rate…', style: muted),
        ],
      );
    }

    if (_quoteFailed || _quote == null) {
      return Text(
        "Couldn't get the $_currency exchange rate. Check your connection.",
        style: const TextStyle(fontSize: 12, color: AppColors.expense),
      );
    }

    final q = _quote!;
    final rateText = formatRate(q.rate, base: _baseCurrency, foreign: _currency!);
    final entered = _enteredAmount;
    final converted = (entered != null && entered > 0)
        ? '≈ ${settings.formatAmountFull(roundMoney(entered / q.rate))}  ·  '
        : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: converted,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _typeColor,
            ),
          ),
          TextSpan(text: rateText, style: muted),
          if (q.estimated)
            TextSpan(text: '  (offline estimate)', style: muted),
        ],
      ),
    );
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
                  onChanged: (_) {
                    if (_isForeign) setState(() {}); // refresh "≈ €…"
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    prefixIcon: const Icon(
                      Icons.attach_money,
                      color: AppColors.darkCyan,
                    ),
                    suffixIcon: _buildCurrencyChip(),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Please enter a valid number';
                    }
                    if (parsed <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    // Foreign amounts are checked after conversion.
                    if (parsed > (_isForeign ? 1e12 : 999999999)) {
                      return 'Amount is too large';
                    }
                    return null;
                  },
                ),
                if (_isForeign)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: _buildConversionPreview(context),
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
                    onPressed: _saving ? null : _submitForm,
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
