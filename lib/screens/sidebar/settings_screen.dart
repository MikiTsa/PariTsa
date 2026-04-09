import 'dart:io';

import 'package:flutter/material.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/biometric_service.dart';
import 'package:expenses_tracker/services/wallet_notification_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

// ─── Currency catalogue ────────────────────────────────────────────────────────

class _Currency {
  final String code;
  final String symbol;
  final String name;
  const _Currency(this.code, this.symbol, this.name);
}

const _kCurrencies = [
  _Currency('EUR', '€',    'Euro'),
  _Currency('USD', '\$',   'US Dollar'),
  _Currency('GBP', '£',    'British Pound'),
  _Currency('CHF', 'Fr',   'Swiss Franc'),
  _Currency('JPY', '¥',    'Japanese Yen'),
  _Currency('CNY', '¥',    'Chinese Yuan'),
  _Currency('CAD', 'CA\$', 'Canadian Dollar'),
  _Currency('AUD', 'A\$',  'Australian Dollar'),
  _Currency('INR', '₹',    'Indian Rupee'),
  _Currency('BRL', 'R\$',  'Brazilian Real'),
  _Currency('RUB', '₽',    'Russian Ruble'),
  _Currency('SEK', 'kr',   'Swedish Krona'),
  _Currency('NOK', 'kr',   'Norwegian Krone'),
  _Currency('DKK', 'kr',   'Danish Krone'),
  _Currency('PLN', 'zł',   'Polish Złoty'),
  _Currency('RON', 'lei',  'Romanian Leu'),
  _Currency('BGN', 'лв',   'Bulgarian Lev'),
  _Currency('HUF', 'Ft',   'Hungarian Forint'),
  _Currency('CZK', 'Kč',   'Czech Koruna'),
  _Currency('TRY', '₺',    'Turkish Lira'),
];

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
  const SettingsScreen({super.key});

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
              // Currency
              _SettingsRow(
                icon: Icons.currency_exchange,
                title: 'Currency',
                trailingText: '${settings.currencySymbol}  ${settings.currency}',
                onTap: () => _showCurrencyPicker(context, settings),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── General ───────────────────────────────────────────────────────
          _SectionLabel('General'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
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

          const SizedBox(height: 32),
        ],
      ),
    );
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

  void _showCurrencyPicker(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CurrencyPicker(
        current: settings.currency,
        onSelected: (code) {
          settings.setCurrency(code);
          Navigator.pop(sheetCtx);
        },
      ),
    );
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

// ─── Currency picker bottom sheet ──────────────────────────────────────────────

class _CurrencyPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _CurrencyPicker({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Select Currency',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.cPrimaryText,
              ),
            ),
          ),
          Divider(height: 1, color: context.cDivider),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _kCurrencies.length,
              itemBuilder: (_, i) {
                final c = _kCurrencies[i];
                final selected = c.code == current;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      c.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                    style:
                        TextStyle(color: context.cMutedText, fontSize: 12),
                  ),
                  trailing: selected
                      ? Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () => onSelected(c.code),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
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
