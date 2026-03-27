import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:expenses_tracker/screens/auth/auth_wrapper.dart';
import 'package:expenses_tracker/providers/app_settings.dart';
import 'package:expenses_tracker/services/local_notification_service.dart';
import 'package:expenses_tracker/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.instance.init();
  final settings = AppSettings();
  await settings.load();
  runApp(MyApp(settings: settings));
}

class MyApp extends StatefulWidget {
  final AppSettings settings;
  const MyApp({super.key, required this.settings});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.settings.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: MaterialApp(
        title: 'PariTsa',
        debugShowCheckedModeBanner: false,
        themeMode: widget.settings.themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const AuthWrapper(),
      ),
    );
  }
}
