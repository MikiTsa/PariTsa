import 'package:expenses_tracker/models/shared_tracker.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';
import 'package:expenses_tracker/widgets/split_bar.dart';
import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';

class SharedTransactionForm extends StatefulWidget {
  final SharedTracker tracker;
  final SharedTransaction? initialTransaction;
  final void Function(SharedTransaction) onSave;

  const SharedTransactionForm({
    super.key,
    required this.tracker,
    this.initialTransaction,
    required this.onSave,
  });

  @override
  State<SharedTransactionForm> createState() => _SharedTransactionFormState();
}

class _SharedTransactionFormState extends State<SharedTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String? _category;
  List<String> _categories = [];
  late List<_SplitEntry> _splitEntries;
  late String _currentUserUid;
  bool _saving = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseService().currentUserId ?? '';

    final initial = widget.initialTransaction;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _totalAmountCtrl.text = initial.totalAmount.toStringAsFixed(2);
      _noteCtrl.text = initial.note ?? '';
      _tagCtrl.text = initial.tag ?? '';
      _date = initial.date;
      // Seed from the current user's own split.myCategory, falling back to
      // the shared tx.category (handles move-to-shared pre-fill).
      _category = initial.splitFor(_currentUserUid)?.myCategory
          ?? initial.category;
      _splitEntries = widget.tracker.members.map((m) {
        final existingSplit = initial.splitFor(m.uid);
        return _SplitEntry(
          member: m,
          controller: TextEditingController(
            text: existingSplit != null
                ? existingSplit.amount.toStringAsFixed(2)
                : '',
          ),
          myCategory: existingSplit?.myCategory,
        );
      }).toList();
    } else {
      _splitEntries = widget.tracker.members.map((m) => _SplitEntry(
        member: m,
        controller: TextEditingController(),
      )).toList();
    }

    _setupSplitListeners();
    _loadCategories();
  }

  /// Load the current user's personal expense categories for use as analytics
  /// buckets. Each member independently picks from their own vocabulary.
  Future<void> _loadCategories() async {
    final cats = await FirebaseService().getCategories(TransactionType.expense);
    if (!mounted) return;
    setState(() {
      _categories = cats;
      // Keep selection visible even if it isn't in the user's personal list.
      if (_category != null && !_categories.contains(_category)) {
        _categories = [_category!, ..._categories];
      }
    });
  }

  void _setupSplitListeners() {
    if (_splitEntries.length == 2) {
      // For 2-person trackers: auto-fill the other field with the remainder.
      for (var i = 0; i < 2; i++) {
        final thisIdx = i;
        final otherIdx = 1 - i;
        _splitEntries[thisIdx].controller.addListener(() {
          setState(() {});
          if (_syncing || _totalAmount <= 0) return;
          _syncing = true;
          final val = double.tryParse(
                  _splitEntries[thisIdx].controller.text.replaceAll(',', '.')) ??
              0;
          final rem =
              double.parse((_totalAmount - val).toStringAsFixed(2));
          _splitEntries[otherIdx].controller.text =
              rem >= 0 ? rem.toStringAsFixed(2) : '';
          _syncing = false;
        });
      }
    } else {
      for (final entry in _splitEntries) {
        entry.controller.addListener(() => setState(() {}));
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalAmountCtrl.dispose();
    _noteCtrl.dispose();
    _tagCtrl.dispose();
    for (final e in _splitEntries) {
      e.controller.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_totalAmountCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _splitSum => _splitEntries.fold(
        0,
        (sum, e) =>
            sum + (double.tryParse(e.controller.text.replaceAll(',', '.')) ?? 0),
      );

  double get _remaining =>
      double.parse((_totalAmount - _splitSum).toStringAsFixed(2));

  bool get _splitsValid =>
      (_totalAmount - _splitSum).abs() < 0.01 && _totalAmount > 0;

  void _showCategorySheet(BuildContext context) {
    final addCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void addCategory() {
            final name = addCtrl.text.trim();
            if (name.isEmpty) return;
            if (_categories.contains(name)) {
              // Already exists — just select it
              setState(() {
                _category = name;
                for (final e in _splitEntries) {
                  if (e.member.uid == _currentUserUid) e.myCategory = name;
                }
              });
              Navigator.pop(ctx);
              return;
            }
            // Persist to the tracker and update local list
            FirebaseService().addCategoryToSharedTracker(
              widget.tracker.id, name,
            );
            setState(() {
              _categories = [..._categories, name];
              _category = name;
              for (final e in _splitEntries) {
                if (e.member.uid == _currentUserUid) e.myCategory = name;
              }
            });
            Navigator.pop(ctx);
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
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
                        'My Category',
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
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: _categories.map((cat) {
                        final selected = _category == cat;
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          title: Text(
                            cat,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : context.cPrimaryText,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _category = cat;
                              for (final e in _splitEntries) {
                                if (e.member.uid == _currentUserUid) {
                                  e.myCategory = cat;
                                }
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Add a category…',
                              hintStyle: TextStyle(color: context.cMutedText),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => addCategory(),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: addCtrl.text.trim().isEmpty
                              ? context.cMutedText
                              : AppColors.primary,
                          onPressed: addCtrl.text.trim().isEmpty
                              ? null
                              : addCategory,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _splitEqually() {
    if (_totalAmount <= 0) return;
    final count = _splitEntries.length;
    final each = _totalAmount / count;
    final rounded = double.parse(each.toStringAsFixed(2));
    // Give any rounding remainder to the first entry
    final remainder =
        double.parse((_totalAmount - rounded * count).toStringAsFixed(2));

    for (var i = 0; i < _splitEntries.length; i++) {
      final value = i == 0 ? rounded + remainder : rounded;
      _splitEntries[i].controller.text = value.toStringAsFixed(2);
    }
  }

  void _showTagDialog() {
    final tempController = TextEditingController(text: _tagCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tag (Optional)'),
        content: TextField(
          controller: tempController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Vacation 2025, Side project',
            prefixIcon: Icon(Icons.label_outline, color: AppColors.darkCyan),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _tagCtrl.text = '');
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _tagCtrl.text = tempController.text.trim());
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_splitsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Splits must add up to ${AppSettingsScope.of(context).formatAmount(_totalAmount)}',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final splits = _splitEntries
        .where((e) =>
            (double.tryParse(e.controller.text.replaceAll(',', '.')) ?? 0) > 0)
        .map((e) => Split(
              uid: e.member.uid,
              displayName: e.member.displayName,
              amount: double.parse(e.controller.text.replaceAll(',', '.')),
              // Store the current user's personal category on their own split.
              // Other members' splits keep whatever myCategory they already had.
              myCategory: e.member.uid == _currentUserUid
                  ? _category
                  : e.myCategory,
            ))
        .toList();

    final tx = SharedTransaction(
      id: widget.initialTransaction?.id,
      title: _titleCtrl.text.trim(),
      totalAmount: _totalAmount,
      date: _date,
      splits: splits,
      category: _category,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
      // On new transactions, stamp the sender's UID so the Cloud Function
      // knows who to exclude from FCM notifications.
      // On edits, preserve the original creator (notifications are not sent on update).
      createdByUid: widget.initialTransaction?.createdByUid ?? _currentUserUid,
    );

    widget.onSave(tx);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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

              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initialTransaction == null
                          ? 'Add shared expense'
                          : 'Edit shared expense',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.cPrimaryText,
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
                          color: _tagCtrl.text.isNotEmpty
                              ? AppColors.primary
                              : AppColors.mutedText,
                          size: 26,
                        ),
                        if (_tagCtrl.text.isNotEmpty)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Total amount
              TextFormField(
                controller: _totalAmountCtrl,
                decoration: const InputDecoration(labelText: 'Total amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n =
                      double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0;
                  if (n <= 0) return 'Enter a valid amount';
                  if (n > 999999999) return 'Amount too large';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today_outlined,
                    color: context.cSecondaryText, size: 20),
                title: Text(
                  settings.formatDate(_date),
                  style: TextStyle(color: context.cPrimaryText),
                ),
                onTap: _pickDate,
              ),

              // Category
              if (_categories.isNotEmpty) ...[
                InkWell(
                  onTap: () => _showCategorySheet(context),
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'My category (optional)',
                      prefixIcon: Icon(Icons.category_outlined,
                          color: AppColors.darkCyan),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _category ?? 'Select a category',
                          style: TextStyle(
                            color: _category != null
                                ? context.cPrimaryText
                                : context.cMutedText,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: context.cMutedText, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Note
              TextFormField(
                controller: _noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 12),

              // ── Splits section ────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Split',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.cPrimaryText,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _splitEqually,
                    icon: const Icon(Icons.balance, size: 16),
                    label: const Text('Split equally'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Split bar preview
              if (_totalAmount > 0 && _splitSum > 0) ...[
                SplitBar(
                  totalAmount: _totalAmount,
                  splits: _splitEntries
                      .where((e) =>
                          (double.tryParse(
                                  e.controller.text.replaceAll(',', '.')) ??
                              0) >
                          0)
                      .map((e) => Split(
                            uid: e.member.uid,
                            displayName: e.member.displayName,
                            amount: double.parse(
                                e.controller.text.replaceAll(',', '.')),
                          ))
                      .toList(),
                  members: widget.tracker.members,
                  height: 12,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _splitsValid
                          ? ''
                          : _remaining > 0
                              ? 'Remaining: ${settings.formatAmount(_remaining)}'
                              : 'Over by: ${settings.formatAmount(-_remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _splitsValid
                            ? AppColors.income
                            : AppColors.expense,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Per-member amount fields
              ..._splitEntries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        // Colour dot + initials
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              entry.member.color.withValues(alpha: 0.2),
                          child: Text(
                            _initials(entry.member.displayName),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: entry.member.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: entry.controller,
                            decoration: InputDecoration(
                              labelText: entry.member.displayName,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _SplitEntry {
  final TrackerMember member;
  final TextEditingController controller;
  // Preserved across edits; updated when this user changes their category.
  String? myCategory;
  _SplitEntry({required this.member, required this.controller, this.myCategory});
}
