import 'package:flutter/material.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/biometric_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

// ─── Gate widget — wraps any child and enforces biometric lock ────────────────

class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  bool _locked = true;
  DateTime? _backgroundedAt;
  static const _lockAfter = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-prompt after the first frame so context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlockIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null && DateTime.now().difference(bg) >= _lockAfter) {
        setState(() => _locked = true);
        _tryUnlockIfNeeded();
      }
      _backgroundedAt = null;
    }
  }

  Future<void> _tryUnlockIfNeeded() async {
    if (!mounted) return;
    final settings = AppSettingsScope.of(context);
    if (!settings.biometricLock) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    final success = await BiometricService.authenticate();
    if (mounted && success) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = AppSettingsScope.of(context).biometricLock;
    if (!biometricEnabled || !_locked) return widget.child;
    return _LockScreen(onUnlock: _tryUnlockIfNeeded);
  }
}

// ─── Lock screen UI ───────────────────────────────────────────────────────────

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // App name
              Text(
                'PariTsa',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: context.cPrimaryText,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              // Lock icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 52,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'App is locked',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.cPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Authenticate to continue',
                style: TextStyle(
                  fontSize: 14,
                  color: context.cMutedText,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Unlock'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
        ),
    );
  }
}
