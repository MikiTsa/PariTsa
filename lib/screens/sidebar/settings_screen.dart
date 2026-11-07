import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenses_tracker/models/balance_reset.dart';
import 'package:expenses_tracker/models/currency.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/balance_calculator.dart';
import 'package:expenses_tracker/services/biometric_service.dart';
import 'package:expenses_tracker/services/exchange_rate_service.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/widgets/currency_picker.dart';
import 'package:expenses_tracker/services/wallet_notification_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

// ─── Date-format catalogue ─────────────────────────────────────────────────────

class _DateFmt {
  final String key;
  final String label;
  final String example;
  const _DateFmt(this.key, this.label, this.example);
}

const _kDateFormats = [
  _DateFmt('yMMMd',      'Mar 26, 2026', 'Month Day, Year'),
  _DateFmt('dd/MM/yyyy', '26/03/2026',   'Day/Month/Year'),
  _DateFmt('MM/dd/yyyy', '03/26/2026',   'Month/Day/Year'),
  _DateFmt('yyyy-MM-dd', '2026-03-26',   'ISO 8601'),
];

// ─── Tab catalogue ─────────────────────────────────────────────────────────────

const _kTabs = [
  (0, AppColors.expense, 'Expenses'),
  (1, AppColors.income,  'Incomes'),
  (2, AppColors.saving,  'Savings'),
];

// ─── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  /// Live balance/savings from HomeScreen. The Data → Reset section is only
  /// shown when this is provided.
  final BalanceTotals Function()? currentTotals;

  const SettingsScreen({super.key, this.currentTotals});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cAppBar,
        foregroundColor: context.cPrimaryText,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.cPrimaryText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionLabel('Appearance'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              // Theme
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Theme',
                trailingText: _themeLabel(settings.themeMode),
                onTap: () => _showThemePicker(context, settings),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── General ───────────────────────────────────────────────────────
          _SectionLabel('General'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              // Default currency — every amount is stored in this currency
              _SettingsRow(
                icon: Icons.currency_exchange,
                title: 'Default currency',
                trailingText: '${settings.currencySymbol}  ${settings.currency}',
                onTap: () => _changeDefaultCurrency(context, settings),
              ),
              // Date format
              _SettingsRow(
                icon: Icons.calendar_today_outlined,
                title: 'Date format',
                trailingText: _kDateFormats
                    .firstWhere((f) => f.key == settings.dateFormat,
                        orElse: () => _kDateFormats.first)
                    .label,
                onTap: () => _showDateFormatPicker(context, settings),
              ),
              // Default tab
              _SettingsRow(
                icon: Icons.tab_outlined,
                title: 'Default tab',
                trailingWidget: _TabBadge(tab: settings.defaultTab),
                onTap: () => _showTabPicker(context, settings),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Security ──────────────────────────────────────────────────────
          _SectionLabel('Security'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              const _BiometricRow(),
            ],
          ),

          const SizedBox(height: 24),

          // ── Integrations ──────────────────────────────────────────────────
          _SectionLabel('Integrations'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              const _WalletRow(),
            ],
          ),

          // ── Data ──────────────────────────────────────────────────────────
          if (currentTotals != null) ...[
            const SizedBox(height: 24),
            _SectionLabel('Data'),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.restart_alt,
                  title: 'Reset balance or savings',
                  onTap: () => _showResetSheet(context),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  static String _resetLabel(ResetTarget target) => switch (target) {
        ResetTarget.balance => 'Current Balance',
        ResetTarget.savings => 'Total Savings',
      };

  void _showResetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ResetSheet(
        totals: currentTotals!(),
        onReset: (target) {
          Navigator.pop(sheetCtx);
          _confirmReset(context, target);
        },
        onUndo: (reset) {
          Navigator.pop(sheetCtx);
          _confirmUndo(context, reset);
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, ResetTarget target) async {
    final totals = currentTotals!();
    final current =
        target == ResetTarget.balance ? totals.balance : totals.savings;

    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _ResetAmountDialog(target: target, currentAmount: current),
    );
    if (amount == null || !context.mounted) return;

    final settings = AppSettingsScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseService().addReset(BalanceReset(
        target: target,
        date: DateTime.now(),
        amount: amount,
        previousAmount: current,
      ));
      messenger.showSnackBar(SnackBar(
        content: Text(
          '${_resetLabel(target)} reset to ${settings.formatAmountFull(amount)}',
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not reset: $e'),
        backgroundColor: AppColors.expense,
      ));
    }
  }

  Future<void> _confirmUndo(BuildContext context, BalanceReset reset) async {
    final settings = AppSettingsScope.of(context);
    final label = _resetLabel(reset.target);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Undo $label reset?'),
        content: Text(
          'The reset from ${settings.formatDate(reset.date)} will be removed, '
          'along with its marker in History. $label will be calculated as '
          'it was before that reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Undo reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseService().deleteReset(reset.id);
      messenger.showSnackBar(SnackBar(content: Text('$label reset undone')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not undo: $e'),
        backgroundColor: AppColors.expense,
      ));
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light  => 'Light',
        ThemeMode.dark   => 'Dark',
      };

  void _showThemePicker(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ThemePickerSheet(
        current: settings.themeMode,
        onSelected: (mode) {
          settings.setThemeMode(mode);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  /// Pick a new default currency, then convert every stored amount to it at
  /// today's rate so the balance keeps meaning the same thing.
  Future<void> _changeDefaultCurrency(
    BuildContext context,
    AppSettings settings,
  ) async {
    final oldCode = settings.currency;
    final newCode = await showCurrencyPicker(
      context,
      current: oldCode,
      title: 'Default Currency',
    );
    if (newCode == null || newCode == oldCode || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    // Units of the new currency per 1 unit of the old one — must be live.
    final quote = await ExchangeRateService.instance.quote(
      from: newCode,
      to: oldCode,
      allowCached: false,
    );
    if (!context.mounted) return;
    if (quote == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          "Couldn't get today's exchange rate. Check your connection and try again.",
        ),
        backgroundColor: AppColors.expense,
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Switch to $newCode?'),
        content: Text(
          'All your expenses, incomes, savings and resets will be converted '
          'from $oldCode to $newCode at today\'s rate:\n\n'
          '${formatRate(quote.rate, base: oldCode, foreign: newCode)}\n\n'
          'Shared tracker amounts are not converted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Blocking progress dialog while the batches run.
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text('Converting to $newCode…')),
            ],
          ),
        ),
      ),
    );

    try {
      final count = await FirebaseService().convertAllToCurrency(
        newBase: newCode,
        factor: quote.rate,
      );
      await settings.setCurrency(newCode);
      await FirebaseService().setBaseCurrency(newCode);
      unawaited(ExchangeRateService.instance.prewarm(newCode));
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Converted $count transactions to $newCode'),
      ));
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Conversion failed: $e'),
        backgroundColor: AppColors.expense,
      ));
    }
  }

  void _showDateFormatPicker(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _DateFormatSheet(
        current: settings.dateFormat,
        onSelected: (key) {
          settings.setDateFormat(key);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  void _showTabPicker(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _TabPickerSheet(
        current: settings.defaultTab,
        onSelected: (val) {
          settings.setDefaultTab(val);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: context.cMutedText,
        ),
      ),
    );
  }
}

// ─── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.cDivider.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.cPrimaryText.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 1,
                  indent: 54,
                  color: context.cDivider.withValues(alpha: 0.5),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: context.cPrimaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Trailing
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingText!,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, color: context.cMutedText, size: 20),
            ] else if (trailingWidget != null) ...[
              const SizedBox(width: 8),
              trailingWidget!,
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, color: context.cMutedText, size: 20),
            ] else if (onTap != null) ...[
              Icon(Icons.chevron_right, color: context.cMutedText, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Tab badge ─────────────────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int tab;
  const _TabBadge({required this.tab});

  @override
  Widget build(BuildContext context) {
    final t = _kTabs[tab];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: t.$2, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          t.$3,
          style: TextStyle(
            color: t.$2,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─── Theme picker bottom sheet ─────────────────────────────────────────────────

const _kThemeModes = [
  (ThemeMode.system, Icons.brightness_auto, 'System'),
  (ThemeMode.light,  Icons.light_mode,      'Light'),
  (ThemeMode.dark,   Icons.dark_mode,       'Dark'),
];

class _ThemePickerSheet extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;
  const _ThemePickerSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Theme',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.cPrimaryText,
              ),
            ),
          ),
          Divider(height: 1, color: context.cDivider),
          ..._kThemeModes.map((t) {
            final selected = t.$1 == current;
            return ListTile(
              leading: Icon(t.$2,
                  color: selected ? AppColors.primary : context.cMutedText),
              title: Text(
                t.$3,
                style: TextStyle(
                  color: context.cPrimaryText,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () => onSelected(t.$1),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Date format bottom sheet ──────────────────────────────────────────────────

class _DateFormatSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _DateFormatSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Date Format',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.cPrimaryText,
              ),
            ),
          ),
          Divider(height: 1, color: context.cDivider),
          ..._kDateFormats.map((fmt) {
            final selected = fmt.key == current;
            return ListTile(
              title: Text(
                fmt.label,
                style: TextStyle(
                  color: context.cPrimaryText,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                fmt.example,
                style: TextStyle(color: context.cMutedText, fontSize: 12),
              ),
              trailing: selected
                  ? Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () => onSelected(fmt.key),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Tab picker bottom sheet ───────────────────────────────────────────────────

class _TabPickerSheet extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelected;
  const _TabPickerSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Default Tab',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.cPrimaryText,
              ),
            ),
          ),
          Divider(height: 1, color: context.cDivider),
          ..._kTabs.map((t) {
            final selected = t.$1 == current;
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(left: 4),
                decoration:
                    BoxDecoration(color: t.$2, shape: BoxShape.circle),
              ),
              title: Text(
                t.$3,
                style: TextStyle(
                  color: context.cPrimaryText,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? Icon(Icons.check_circle, color: t.$2)
                  : null,
              onTap: () => onSelected(t.$1),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Biometric lock row ────────────────────────────────────────────────────────

class _BiometricRow extends StatefulWidget {
  const _BiometricRow();

  @override
  State<_BiometricRow> createState() => _BiometricRowState();
}

class _BiometricRowState extends State<_BiometricRow> {
  bool _available = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    BiometricService.isAvailable().then((v) {
      if (mounted) setState(() { _available = v; _loading = false; });
    });
  }

  Future<void> _toggle(AppSettings settings, bool value) async {
    if (value) {
      // Verify biometrics work before enabling
      final success = await BiometricService.authenticate();
      if (!success) return;
    }
    await settings.setBiometricLock(value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final enabled  = settings.biometricLock;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.fingerprint, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric lock',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.cPrimaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loading
                      ? 'Checking availability…'
                      : _available
                          ? 'Lock app on background'
                          : 'Not available on this device',
                  style: TextStyle(fontSize: 12, color: context.cMutedText),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: enabled,
              onChanged: _available ? (v) => _toggle(settings, v) : null,
              activeThumbColor: AppColors.primary,
            ),
        ],
      ),
    );
  }
}

// ─── Google Wallet row ─────────────────────────────────────────────────────────

class _WalletRow extends StatefulWidget {
  const _WalletRow();

  @override
  State<_WalletRow> createState() => _WalletRowState();
}

class _WalletRowState extends State<_WalletRow> with WidgetsBindingObserver {
  final _service = WalletNotificationService();
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final granted = await _service.isPermissionGranted();
    if (mounted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _service.openPermissionSettings,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.wallet, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Wallet',
                        style: TextStyle(
                          fontSize: 15,
                          color: context.cPrimaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Auto-capture payment notifications',
                        style: TextStyle(fontSize: 12, color: context.cMutedText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _granted
                        ? Colors.green.withValues(alpha: 0.12)
                        : AppColors.expense.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _granted ? Icons.check_circle_outline : Icons.block_outlined,
                        size: 13,
                        color: _granted ? Colors.green : AppColors.expense,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _granted ? 'Granted' : 'Not granted',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _granted ? Colors.green : AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: context.cMutedText, size: 20),
              ],
            ),
          ),
        ),
        // Xiaomi/MIUI devices reset the Autostart permission after every app
        // update, which silently kills the notification listener service even
        // when notification access is granted.
        if (_granted && Platform.isAndroid)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: context.cMutedText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Xiaomi/MIUI only: also enable Autostart — '
                    'Settings → Apps → Permissions → Background Autostart → PariTsa'
                    'MIUI resets this after every app update.',
                    style: TextStyle(fontSize: 11, color: context.cMutedText),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Reset: choose balance or savings ──────────────────────────────────────────

class _ResetSheet extends StatelessWidget {
  final BalanceTotals totals;
  final ValueChanged<ResetTarget> onReset;
  final ValueChanged<BalanceReset> onUndo;

  const _ResetSheet({
    required this.totals,
    required this.onReset,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _SheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'Reset',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.cPrimaryText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Start counting again from an amount you choose. '
                'No transactions are deleted.',
                style: TextStyle(fontSize: 13, color: context.cSecondaryText),
              ),
            ),
            Divider(height: 1, color: context.cDivider),
            _option(
              context,
              target: ResetTarget.balance,
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              amount: totals.balance,
            ),
            _option(
              context,
              target: ResetTarget.savings,
              icon: Icons.savings_outlined,
              color: AppColors.saving,
              amount: totals.savings,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required ResetTarget target,
    required IconData icon,
    required Color color,
    required double amount,
  }) {
    final settings = AppSettingsScope.of(context);
    final active = BalanceCalculator.latestReset(totals.resets, target);
    final amountText = settings.formatAmountFull(amount);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        SettingsScreen._resetLabel(target),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: context.cPrimaryText,
        ),
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: amountText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: amount < 0 ? AppColors.expense : context.cSecondaryText,
              ),
            ),
            if (active != null)
              TextSpan(
                text: '  ·  since ${settings.formatDate(active.date)}',
                style: TextStyle(color: context.cMutedText),
              ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active != null)
            TextButton.icon(
              onPressed: () => onUndo(active),
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Undo'),
              style: TextButton.styleFrom(foregroundColor: context.cMutedText),
            ),
          Icon(Icons.chevron_right, color: context.cMutedText, size: 20),
        ],
      ),
      onTap: () => onReset(target),
    );
  }
}

// ─── Reset: choose the new amount and confirm ──────────────────────────────────

class _ResetAmountDialog extends StatefulWidget {
  final ResetTarget target;
  final double currentAmount;

  const _ResetAmountDialog({required this.target, required this.currentAmount});

  @override
  State<_ResetAmountDialog> createState() => _ResetAmountDialogState();
}

class _ResetAmountDialogState extends State<_ResetAmountDialog> {
  final _controller = TextEditingController();
  String? _error;

  bool get _isBalance => widget.target == ResetTarget.balance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Many Android number keyboards have no minus key, so the balance field
  // gets a ± button instead.
  void _toggleSign() {
    final text = _controller.text;
    _controller.text = text.startsWith('-') ? text.substring(1) : '-$text';
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  void _submit() {
    final raw = _controller.text.trim().replaceAll(',', '.');
    final value = (raw.isEmpty || raw == '-') ? 0.0 : double.tryParse(raw);

    final String? error;
    if (value == null) {
      error = 'Enter a valid amount';
    } else if (value.abs() > 999999999) {
      error = 'Amount is too large';
    } else if (!_isBalance && value < 0) {
      error = 'Savings cannot be negative';
    } else {
      error = null;
    }

    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, double.parse(value!.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final color = _isBalance ? AppColors.primary : AppColors.saving;

    return AlertDialog(
      scrollable: true,
      title: Text('Reset ${SettingsScreen._resetLabel(widget.target)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Currently ',
              style: TextStyle(color: context.cSecondaryText),
              children: [
                TextSpan(
                  text: settings.formatAmountFull(widget.currentAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.currentAmount < 0
                        ? AppColors.expense
                        : context.cPrimaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the amount to start from. Your transactions stay in '
            'History and Analytics, and a reset marker is added to History.',
            style: TextStyle(fontSize: 13, color: context.cMutedText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: _isBalance,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(_isBalance ? r'^-?[0-9]*[.,]?[0-9]{0,2}' : r'^[0-9]*[.,]?[0-9]{0,2}'),
              ),
            ],
            decoration: InputDecoration(
              labelText: 'New amount',
              hintText: '0.00',
              prefixText: '${settings.currencySymbol} ',
              errorText: _error,
              suffixIcon: _isBalance
                  ? IconButton(
                      tooltip: 'Positive / negative',
                      icon: const Icon(Icons.exposure),
                      onPressed: _toggleSign,
                    )
                  : null,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: color),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

// ─── Shared sheet handle ───────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.cMutedText.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
