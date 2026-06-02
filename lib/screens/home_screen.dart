import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final identity = user?.phone ?? user?.email ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text('Balanzo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5))),
        backgroundColor: const Color(0xFF09090B),
        foregroundColor: const Color(0xFFF2F2F5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async => await AuthService.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181C),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome to Balanzo!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5)),
              ),
              const SizedBox(height: 10),
              Text(
                identity,
                style: const TextStyle(fontSize: 15, color: Color(0xFF8888A0)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Your expense tracking dashboard is coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8888A0), fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

