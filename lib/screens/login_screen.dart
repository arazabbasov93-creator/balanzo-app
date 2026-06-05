import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/crash_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _googleLoading = false;
  bool _appleLoading = false;

  bool get _anyLoading => _googleLoading || _appleLoading;

  Future<void> _signInWithGoogle() async {
    if (_anyLoading) return;
    setState(() => _googleLoading = true);
    try {
      final response = await AuthService.signInWithGoogle();
      final user = response.user;
      if (user != null) {
        await AuthService.upsertUser(user);
        await CrashService.setUser();
        final createdAt = user.createdAt;
        final isNew = createdAt.isNotEmpty &&
            DateTime.now()
                    .difference(DateTime.tryParse(createdAt) ?? DateTime(2000))
                    .inSeconds <
                30;
        if (isNew) await AnalyticsService.log('account_created');
      }
      // AuthGate handles navigation automatically on auth state change
    } catch (e, st) {
      debugPrint('[Login] Google sign-in error: $e\n$st');
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (_anyLoading) return;
    setState(() => _appleLoading = true);
    try {
      final response = await AuthService.signInWithApple();
      final user = response.user;
      if (user != null) {
        await AuthService.upsertUser(user);
        await CrashService.setUser();
        final createdAt = user.createdAt;
        final isNew = createdAt.isNotEmpty &&
            DateTime.now()
                    .difference(DateTime.tryParse(createdAt) ?? DateTime(2000))
                    .inSeconds <
                30;
        if (isNew) await AnalyticsService.log('account_created');
      }
      // AuthGate handles navigation automatically on auth state change
    } catch (e, st) {
      debugPrint('[Login] Apple sign-in error: $e\n$st');
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _friendlyError(Object e) {
    if (e is AuthException) {
      final code = e.statusCode;
      if (code == '401' || code == '400') {
        return 'Sign-in rejected by server. Check provider settings in Supabase Auth.';
      }
      return e.message;
    }
    final msg = e.toString();
    if (msg.contains('cancelled') || msg.contains('canceled')) {
      return 'Sign-in cancelled.';
    }
    if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In not configured for this app build (SHA-1 / Firebase).';
    }
    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'Cannot reach server. Check Wi‑Fi/mobile data and try again.';
    }
    return msg.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _buildLogo(),
              const SizedBox(height: 64),
              const Text(
                'Sign in or create account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred sign-in method',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),
              _GoogleButton(
                loading: _googleLoading,
                disabled: _appleLoading,
                onPressed: _signInWithGoogle,
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 16),
                _AppleButton(
                  loading: _appleLoading,
                  disabled: _googleLoading,
                  onPressed: _signInWithApple,
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Balanzo',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Family budget made simple',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  const _GoogleButton({
    required this.loading,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = disabled || loading;
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: inactive ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: disabled ? Colors.grey.shade200 : Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledForegroundColor: Colors.black87.withValues(alpha: disabled ? 0.4 : 1.0),
          disabledBackgroundColor: Colors.white,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Color(0xFF1B5E20),
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: disabled ? 0.4 : 1.0,
                    child: SvgPicture.asset(
                      'assets/images/google_logo.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: disabled ? Colors.black38 : Colors.black87,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  const _AppleButton({
    required this.loading,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = disabled || loading;
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: inactive ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apple, size: 26, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue with Apple',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
