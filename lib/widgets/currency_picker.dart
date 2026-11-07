import 'package:flutter/material.dart';
import 'package:expenses_tracker/models/currency.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

/// Searchable list of every currency. Resolves to the picked code, or null
/// if dismissed.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String current,
  String title = 'Select Currency',
  Color accent = AppColors.primary,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CurrencyPickerSheet(
      current: current,
      title: title,
      accent: accent,
    ),
  );
}

class _CurrencyPickerSheet extends StatefulWidget {
  final String current;
  final String title;
  final Color accent;

  const _CurrencyPickerSheet({
    required this.current,
    required this.title,
    required this.accent,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String _query = '';

  List<CurrencyInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    // Current selection first, then alphabetical by code.
    final current = findCurrency(widget.current);
    final rest = kCurrencies.where((c) => c.code != widget.current);
    final all = [if (current != null) current, ...rest];
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.code.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q) ||
            c.symbol.toLowerCase() == q)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.8,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cMutedText.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.cPrimaryText,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by name or code',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Divider(height: 1, color: context.cDivider),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No currency found',
                      style: TextStyle(color: context.cMutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final c = items[i];
                      final selected = c.code == widget.current;
                      return ListTile(
                        leading: SizedBox(
                          width: 48,
                          child: Text(
                            c.symbol,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? widget.accent
                                  : context.cSecondaryText,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: TextStyle(
                            color: context.cPrimaryText,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          c.code,
                          style: TextStyle(
                            color: context.cMutedText,
                            fontSize: 12,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle, color: widget.accent)
                            : null,
                        onTap: () => Navigator.pop(context, c.code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
