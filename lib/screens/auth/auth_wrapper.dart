import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expenses_tracker/services/auth_service.dart';
import 'package:expenses_tracker/screens/auth/login_screen.dart';
import 'package:expenses_tracker/screens/biometric_lock_screen.dart';
import 'package:expenses_tracker/screens/home_screen.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

/// Wrapper that shows Login or Home screen based on authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // If user is logged in, show HomeScreen behind the biometric gate
        if (snapshot.hasData && snapshot.data != null) {
          return const BiometricGate(child: HomeScreen());
        }

        // If user is not logged in, show LoginScreen
        return const LoginScreen();
      },
    );
  }
}
