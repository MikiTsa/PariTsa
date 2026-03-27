import 'package:flutter/material.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
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
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader('Appearance'),

          // Theme
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            child: _ThemePicker(
              current: settings.themeMode,
              onChanged: settings.setThemeMode,
            ),
          ),

          // Currency
          _SettingsTile(
            icon: Icons.currency_exchange,
            title: 'Currency',
            trailing: GestureDetector(
              onTap: () => _showCurrencyPicker(context, settings),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${settings.currencySymbol}  ${settings.currency}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: context.cMutedText,
                    size: 20,
                  ),
                ],
              ),
            ),
            onTap: () => _showCurrencyPicker(context, settings),
          ),

          const SizedBox(height: 8),

          // ── General ───────────────────────────────────────────────────────
          _SectionHeader('General'),

          // Date format
          _SettingsTile(
            icon: Icons.calendar_today_outlined,
            title: 'Date format',
            child: _DateFormatPicker(
              current: settings.dateFormat,
              onChanged: settings.setDateFormat,
            ),
          ),

          // Default tab
          _SettingsTile(
            icon: Icons.tab_outlined,
            title: 'Default tab',
            child: _TabPicker(
              current: settings.defaultTab,
              onChanged: settings.setDefaultTab,
            ),
          ),

          const SizedBox(height: 8),

          // ── Integrations ──────────────────────────────────────────────────
          _SectionHeader('Integrations'),

          _SettingsTile(
            icon: Icons.wallet,
            title: 'Google Wallet',
            child: const _WalletPermissionTile(),
          ),

          const SizedBox(height: 24),
        ],
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
}

// ─── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: context.cMutedText,
        ),
      ),
    );
  }
}

// ─── Generic settings tile ─────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? child;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.child,
    this.trailing,
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
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.cPrimaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (child != null) ...[
                    const SizedBox(height: 10),
                    child!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Theme picker ──────────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemePicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto, size: 18),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode, size: 18),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode, size: 18),
          label: Text('Dark'),
        ),
      ],
      selected: {current},
      onSelectionChanged: (sel) => onChanged(sel.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

// ─── Date-format picker ────────────────────────────────────────────────────────

class _DateFormatPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _DateFormatPicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _kDateFormats.map((fmt) {
        final selected = current == fmt.key;
        return ChoiceChip(
          label: Text(fmt.label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onChanged(fmt.key),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          side: BorderSide(
            color: selected ? AppColors.primary : context.cDivider,
          ),
          backgroundColor: context.cInputFill,
          labelStyle: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.primary : context.cMutedText,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}

// ─── Default tab picker ────────────────────────────────────────────────────────

class _TabPicker extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _TabPicker({required this.current, required this.onChanged});

  static const _tabs = [
    (0, AppColors.expense, 'Expenses'),
    (1, AppColors.income,  'Incomes'),
    (2, AppColors.saving,  'Savings'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _tabs[current];

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: current,
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        dropdownColor: context.cCard,
        icon: Icon(Icons.expand_more, color: context.cMutedText, size: 20),
        selectedItemBuilder: (_) => _tabs.map((t) => Center(
          child: Text(
            t.$3,
            style: TextStyle(
              color: selected.$2,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        )).toList(),
        items: _tabs.map((t) => DropdownMenuItem<int>(
          value: t.$1,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: t.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.$3,
                style: TextStyle(
                  color: context.cPrimaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )).toList(),
        onChanged: (val) { if (val != null) onChanged(val); },
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
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cMutedText.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    c.code,
                    style: TextStyle(color: context.cMutedText, fontSize: 12),
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

// ─── Google Wallet permission tile ─────────────────────────────────────────────

class _WalletPermissionTile extends StatefulWidget {
  const _WalletPermissionTile();

  @override
  State<_WalletPermissionTile> createState() => _WalletPermissionTileState();
}

class _WalletPermissionTileState extends State<_WalletPermissionTile>
    with WidgetsBindingObserver {
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
    // Re-check after user returns from system settings.
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
        Text(
          'Auto-capture Google Wallet payment notifications as expenses.',
          style: TextStyle(fontSize: 12, color: context.cMutedText),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _granted
                    ? Colors.green.withValues(alpha: 0.12)
                    : AppColors.expense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
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
                    _granted ? 'Access granted' : 'Access not granted',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _granted ? Colors.green : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!_granted)
              TextButton.icon(
                onPressed: _service.openPermissionSettings,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: const Text('Grant access'),
              ),
          ],
        ),
      ],
    );
  }
}
