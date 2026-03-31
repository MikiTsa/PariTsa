import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

enum _Period { thisMonth, last3Months, thisYear, allTime, custom }

const _kPeriodLabels = {
  _Period.thisMonth:   'This Month',
  _Period.last3Months: 'Last 3 Months',
  _Period.thisYear:    'This Year',
  _Period.allTime:     'All Time',
  _Period.custom:      'Custom Range',
};

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _popNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _popNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _popNotifier.value = true;
      },
      child: Scaffold(
        backgroundColor: context.cBackground,
        appBar: AppBar(
          backgroundColor: context.cAppBar,
          foregroundColor: context.cPrimaryText,
          elevation: 0,
          title: Text(
            'Analytics',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.cPrimaryText,
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
          children: [
            _AnalyticsTab(type: TransactionType.expense, popNotifier: _popNotifier),
            _AnalyticsTab(type: TransactionType.income, popNotifier: _popNotifier),
            _AnalyticsTab(type: TransactionType.saving, popNotifier: _popNotifier),
          ],
        ),
      ),
    );
  }
}

// ─── Per-tab analytics ────────────────────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  final TransactionType type;
  final ValueNotifier<bool> popNotifier;
  const _AnalyticsTab({required this.type, required this.popNotifier});

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = FirebaseService();
  StreamSubscription<dynamic>? _sub;

  List<Transaction> _all = [];
  _Period _period = _Period.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _selectedTag;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.popNotifier.addListener(_onPop);
    _sub = _service.getTransactionsStream(widget.type).listen((list) {
      if (mounted && !widget.popNotifier.value) {
        setState(() { _all = list; _loading = false; });
      }
    });
  }

  void _onPop() {
    if (widget.popNotifier.value) {
      _sub?.cancel();
      _sub = null;
    }
  }

  @override
  void dispose() {
    widget.popNotifier.removeListener(_onPop);
    _sub?.cancel();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<String> get _availableTags {
    final tags = <String>{};
    for (final t in _all) {
      if (t.tag != null && t.tag!.isNotEmpty) tags.add(t.tag!);
    }
    return tags.toList()..sort();
  }

  List<Transaction> get _filtered {
    final now = DateTime.now();
    List<Transaction> result;
    switch (_period) {
      case _Period.thisMonth:
        final cutoff = DateTime(now.year, now.month, 1);
        result = _all.where((t) => !t.date.isBefore(cutoff)).toList();
      case _Period.last3Months:
        final cutoff = DateTime(now.year, now.month - 2, 1);
        result = _all.where((t) => !t.date.isBefore(cutoff)).toList();
      case _Period.thisYear:
        final cutoff = DateTime(now.year, 1, 1);
        result = _all.where((t) => !t.date.isBefore(cutoff)).toList();
      case _Period.allTime:
        result = List.of(_all);
      case _Period.custom:
        if (_customStart != null && _customEnd != null) {
          final end = DateTime(
              _customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
          result = _all
              .where((t) =>
                  !t.date.isBefore(_customStart!) && !t.date.isAfter(end))
              .toList();
        } else {
          result = List.of(_all);
        }
    }
    if (_selectedTag != null) {
      result = result.where((t) => t.tag == _selectedTag).toList();
    }
    return result;
  }

  // ── Aggregations ──────────────────────────────────────────────────────────

  List<MapEntry<String, double>> get _categoryBreakdown {
    final map = <String, double>{};
    for (final t in _filtered) {
      final key = t.category ?? 'Uncategorized';
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, double>> get _monthlyTotals {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i), 1);
      final label = DateFormat.MMM().format(month);
      final total = _all
          .where((t) => t.date.year == month.year && t.date.month == month.month)
          .fold(0.0, (sum, t) => sum + t.amount);
      return MapEntry(label, total);
    });
  }

  // ── Colors ────────────────────────────────────────────────────────────────

  Color get _accentColor => switch (widget.type) {
        TransactionType.expense => AppColors.expense,
        TransactionType.income  => AppColors.income,
        TransactionType.saving  => AppColors.saving,
      };

  // ── Bottom sheet pickers ──────────────────────────────────────────────────

  Future<void> _pickCustomRange(BuildContext context) async {
    final initial = DateTimeRange(
      start: _customStart ?? DateTime.now().subtract(const Duration(days: 30)),
      end: _customEnd ?? DateTime.now(),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initial,
      builder: (context, child) {
        final scheme = ColorScheme.fromSeed(
          seedColor: AppColors.balticBlue,
          brightness: Theme.of(context).brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        );
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: scheme),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _period = _Period.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  void _showPeriodSheet(BuildContext context) {
    final color = _accentColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cCard,
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
                  'Time Period',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.cPrimaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ..._kPeriodLabels.entries.map((e) {
              final selected = _period == e.key;
              final isCustom = e.key == _Period.custom;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  e.value,
                  style: TextStyle(
                    color: selected ? color : context.cPrimaryText,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: color)
                    : isCustom
                        ? Icon(Icons.date_range_outlined,
                            size: 18, color: context.cMutedText)
                        : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (isCustom) {
                    _pickCustomRange(context);
                  } else {
                    setState(() => _period = e.key);
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTagSheet(BuildContext context, List<String> tags) {
    final color = _accentColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cCard,
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
                  'Filter by Tag',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.cPrimaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(
                Icons.label_off_outlined,
                color: _selectedTag == null ? color : context.cMutedText,
                size: 20,
              ),
              title: Text(
                'All Tags',
                style: TextStyle(
                  color: _selectedTag == null ? color : context.cPrimaryText,
                  fontWeight: _selectedTag == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: _selectedTag == null
                  ? Icon(Icons.check_rounded, color: color)
                  : null,
              onTap: () {
                setState(() => _selectedTag = null);
                Navigator.pop(ctx);
              },
            ),
            ...tags.map((tag) {
              final selected = _selectedTag == tag;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  Icons.label_outline,
                  color: selected ? color : context.cMutedText,
                  size: 20,
                ),
                title: Text(
                  tag,
                  style: TextStyle(
                    color: selected ? color : context.cPrimaryText,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: color)
                    : null,
                onTap: () {
                  setState(() => _selectedTag = tag);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    final settings   = AppSettingsScope.of(context);
    final tags       = _availableTags;
    final filtered   = _filtered;
    final total      = filtered.fold(0.0, (s, t) => s + t.amount);
    final count      = filtered.length;
    final avg        = count > 0 ? total / count : 0.0;
    final categories = _categoryBreakdown;
    final monthly    = _monthlyTotals;
    final color      = _accentColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter pills row ──────────────────────────────────────────────
          Row(
            children: [
              _FilterPill(
                icon: Icons.calendar_today_outlined,
                label: _period == _Period.custom &&
                        _customStart != null &&
                        _customEnd != null
                    ? '${DateFormat('d MMM').format(_customStart!)} – ${DateFormat('d MMM').format(_customEnd!)}'
                    : _kPeriodLabels[_period]!,
                isActive: _period != _Period.thisMonth,
                color: color,
                onTap: () => _showPeriodSheet(context),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(width: 8),
                _FilterPill(
                  icon: Icons.label_outline,
                  label: _selectedTag ?? 'All Tags',
                  isActive: _selectedTag != null,
                  color: color,
                  onTap: () => _showTagSheet(context, tags),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          _buildSummaryRow(context, settings, total, count, avg, color),
          const SizedBox(height: 24),

          if (filtered.isEmpty)
            _buildEmptyState(context)
          else ...[
            _buildSectionHeader(context, 'By Category'),
            const SizedBox(height: 12),
            _buildCategoryChart(context, settings, categories, total, color),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Monthly Trend'),
            const SizedBox(height: 12),
            _buildMonthlyChart(context, settings, monthly, color),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 56, color: context.cMutedText),
            const SizedBox(height: 12),
            Text(
              'No data for this period',
              style: TextStyle(color: context.cMutedText, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    AppSettings settings,
    double total,
    int count,
    double avg,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total',
            value: settings.formatAmountFull(total),
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Transactions',
            value: '$count',
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Average',
            value: settings.formatAmountFull(avg),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.cPrimaryText,
      ),
    );
  }

  Widget _buildCategoryChart(
    BuildContext context,
    AppSettings settings,
    List<MapEntry<String, double>> categories,
    double total,
    Color color,
  ) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final maxVal = categories.first.value;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: categories.map((e) {
            final pct = total > 0 ? e.value / total * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.cPrimaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cMutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fill = maxVal > 0
                                ? (e.value / maxVal) * constraints.maxWidth
                                : 0.0;
                            return Stack(
                              children: [
                                Container(
                                  height: 8,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                  height: 8,
                                  width: fill,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: Text(
                          settings.formatAmountFull(e.value),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(
    BuildContext context,
    AppSettings settings,
    List<MapEntry<String, double>> monthly,
    Color color,
  ) {
    final maxVal = monthly.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final currentMonthLabel = DateFormat.MMM().format(DateTime.now());
    const barMaxHeight = 110.0;
    final compactFmt = NumberFormat.compact();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: monthly.map((e) {
              final fraction  = maxVal > 0 ? e.value / maxVal : 0.0;
              final barHeight = fraction * barMaxHeight;
              final isCurrent = e.key == currentMonthLabel;
              final barColor  = isCurrent ? color : color.withValues(alpha: 0.45);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 16,
                        child: e.value > 0
                            ? Text(
                                compactFmt.format(e.value),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? color : context.cMutedText,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: barHeight > 0 ? barHeight : 3,
                        decoration: BoxDecoration(
                          color: barHeight > 0
                              ? barColor
                              : color.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? color : context.cMutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Filter pill button ────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillColor = isActive ? color : context.cMutedText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.10)
              : context.cInputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.6)
                : context.cMutedText.withValues(alpha: 0.25),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: pillColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: pillColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: pillColor),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.cMutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
