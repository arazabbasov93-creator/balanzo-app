import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../diag_log.dart';
import '../app_state.dart';
import '../services/supabase_access.dart';
import '../services/analytics_service.dart';
import '../services/category_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'receipt_capture_screen.dart';
import '../config/app_colors.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _retrying = false;
  bool _listenersWired = false;

  @override
  void initState() {
    super.initState();
    supabaseReadyNotifier.addListener(_onSupabaseReady);
    if (supabaseReady) _wireAuthListeners();
  }

  @override
  void dispose() {
    supabaseReadyNotifier.removeListener(_onSupabaseReady);
    super.dispose();
  }

  void _onSupabaseReady() {
    if (!supabaseReadyNotifier.value || !mounted) return;
    _wireAuthListeners();
    setState(() {});
  }

  void _wireAuthListeners() {
    if (_listenersWired || !supabaseReady) return;
    _listenersWired = true;
    if (SupabaseAccess.clientOrNull?.auth.currentSession != null) {
      CategoryService.refreshCache();
    }
    SupabaseAccess.client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
        CategoryService.refreshCache();
      } else {
        CategoryService.clearCache();
      }
    });
  }

  Future<void> _retryConnect() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await Supabase.initialize(
        url: 'https://mwookghnlhmseayeyycj.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13b29rZ2hubGhtc2VheWV5eWNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzMyMjEsImV4cCI6MjA5NDk0OTIyMX0.lTcGXJ2u5V_jJTzwDQFagCmLE7cRrrRcCPpuAM6E-d8',
      ).timeout(const Duration(seconds: 15));
      supabaseReady = true;
      supabaseReadyNotifier.value = true;
      _wireAuthListeners();
    } catch (e, st) {
      debugPrint('[AuthGate] Supabase retry failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!supabaseReady) {
      diag('AuthGate.build offline-retry');
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Could not connect to Balanzo services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _retrying ? null : _retryConnect,
                  child: _retrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return StreamBuilder<AuthState>(
      stream: SupabaseAccess.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            SupabaseAccess.clientOrNull?.auth.currentSession;
        diag('AuthGate.build session', session != null ? 'logged-in→Dashboard' : 'LoginScreen');
        if (session != null) return const DashboardScreen();
        return const LoginScreen();
      },
    );
  }
}

/// Shown to unauthenticated users who want to try scanning before signing up.
class FirstScanGateway extends StatelessWidget {
  const FirstScanGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  size: 44,
                  color: AppColors.primaryGreenDark,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Try Scanning a Receipt',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan your first receipt to see how Balanzo works. No account needed to try.',
                style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () async {
                  await AnalyticsService.log('first_scan_started');
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReceiptCaptureScreen(isGuestMode: true),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text(
                  'Scan Receipt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen(
                    Theme.of(context).brightness,
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Sign In / Create Account',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
