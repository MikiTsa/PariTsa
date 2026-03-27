import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

enum _Period { thisMonth, last3Months, thisYear, allTime }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
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
        children: const [
          _AnalyticsTab(type: TransactionType.expense),
          _AnalyticsTab(type: TransactionType.income),
          _AnalyticsTab(type: TransactionType.saving),
        ],
      ),
    );
  }
}

// ─── Per-tab analytics ────────────────────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  final TransactionType type;
  const _AnalyticsTab({required this.type});

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _service.getTransactionsStream(widget.type).listen((list) {
      if (mounted) setState(() { _all = list; _loading = false; });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Transaction> get _filtered {
    final now = DateTime.now();
    DateTime? cutoff;
    switch (_period) {
      case _Period.thisMonth:
        cutoff = DateTime(now.year, now.month, 1);
      case _Period.last3Months:
        cutoff = DateTime(now.year, now.month - 2, 1);
      case _Period.thisYear:
        cutoff = DateTime(now.year, 1, 1);
      case _Period.allTime:
        cutoff = null;
    }
    if (cutoff == null) return _all;
    return _all.where((t) => !t.date.isBefore(cutoff!)).toList();
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    final settings    = AppSettingsScope.of(context);
    final filtered    = _filtered;
    final total       = filtered.fold(0.0, (s, t) => s + t.amount);
    final count       = filtered.length;
    final avg         = count > 0 ? total / count : 0.0;
    final categories  = _categoryBreakdown;
    final monthly     = _monthlyTotals;
    final color       = _accentColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodFilter(context),
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

  Widget _buildPeriodFilter(BuildContext context) {
    const labels = {
      _Period.thisMonth:   'This Month',
      _Period.last3Months: 'Last 3 Months',
      _Period.thisYear:    'This Year',
      _Period.allTime:     'All Time',
    };
    final color = _accentColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((e) {
          final selected = _period == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _period = e.key),
              selectedColor: color.withValues(alpha: 0.15),
              checkmarkColor: color,
              backgroundColor: context.cInputFill,
              side: BorderSide(
                color: selected ? color : Colors.transparent,
              ),
              labelStyle: TextStyle(
                color: selected ? color : context.cMutedText,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
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
