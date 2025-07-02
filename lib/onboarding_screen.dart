import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              Text('Welcome to Inventory Manager',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                '• Offline-first: Works without internet.\n'
                '• Scan barcodes/QR for fast SKU entry.\n'
                '• Role-based: Admin, Inventory, Sales.\n'
                '• Export data as CSV/PDF.\n'
                '• All actions are logged for audit.\n',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('Contact support: support@yourcompany.com',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Get Started'),
                onPressed: onFinish,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
