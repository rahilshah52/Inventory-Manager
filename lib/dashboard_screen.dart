import 'package:flutter/material.dart';
import 'inventory_list_screen.dart';
import 'employee_list_screen.dart';
import 'login_screen.dart'; // ← Add this import for LoginScreen
import 'transaction_log_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user['role'];

    String welcomeMessage = 'Welcome!';
    String roleDescription = '';

    if (role == 'admin') {
      welcomeMessage = 'Admin Dashboard';
      roleDescription = 'Full access to all features.';
    } else if (role == 'inventory') {
      welcomeMessage = 'Inventory Dashboard';
      roleDescription = 'Manage and view inventory.';
    } else if (role == 'sales') {
      welcomeMessage = 'Sales Dashboard';
      roleDescription = 'Deliver inventory only.';
    }

    return Scaffold(
      appBar: AppBar(title: Text(welcomeMessage)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.indigo.shade100,
                child: Icon(
                  role == 'admin'
                      ? Icons.admin_panel_settings
                      : role == 'inventory'
                          ? Icons.inventory_2
                          : Icons.delivery_dining,
                  size: 40,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                welcomeMessage,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Role: ${role.toString().toUpperCase()}',
                style: const TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                roleDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryListScreen(user: user),
                    ),
                  );
                },
                icon: const Icon(Icons.inventory_2),
                label: const Text('Go to Inventory'),
              ),
              const SizedBox(height: 16),
              if (role == 'admin')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmployeeListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Manage Employees'),
                ),
              const SizedBox(height: 16),
              // Only admin and inventory can see transaction log
              if (role == 'admin' || role == 'inventory')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionLogScreen(user: user),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View Transaction Log'),
                ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content:
                              const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (shouldLogout) {
                    await Supabase.instance.client.auth.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
