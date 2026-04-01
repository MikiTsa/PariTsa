import 'package:flutter/material.dart';
import 'package:expenses_tracker/services/auth_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      setState(() => _emailSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: Text('Forgot Password', style: TextStyle(color: context.cPrimaryText)),
        backgroundColor: context.cAppBar,
        foregroundColor: context.cPrimaryText,
        iconTheme: IconThemeData(color: context.cPrimaryText),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _emailSent ? _buildSuccessView(context) : _buildFormView(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 80, color: AppColors.primary),
          const SizedBox(height: 16),

          Text(
            'Reset Your Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.cPrimaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            "Enter your email and we'll send you a reset link",
            style: TextStyle(color: context.cSecondaryText, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: AppColors.darkCyan,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 80, color: AppColors.income),
        const SizedBox(height: 16),

        Text(
          'Email Sent!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.cPrimaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          'Check your email for a password reset link.',
          style: TextStyle(color: context.cSecondaryText, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back to Login',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
