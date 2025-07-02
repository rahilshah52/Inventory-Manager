import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/inventory_item.dart';
import 'models/inventory_transaction.dart';
import 'models/employee.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(InventoryItemAdapter());
  Hive.registerAdapter(InventoryTransactionAdapter());
  Hive.registerAdapter(EmployeeAdapter());

  await Hive.openBox<InventoryItem>('inventory');
  await Hive.openBox<InventoryTransaction>('transactions');
  await Hive.openBox<Employee>('employees');

  await Supabase.initialize(
    url: 'https://elmupuxvzoeywkfdqsmy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVsbXVwdXh2em9leXdrZmRxc215Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzMTEwMDMsImV4cCI6MjA2Njg4NzAwM30.fGFKIF7EjnE14-REIzWVq7DUgE1-toRHz_lodEq5C0o',
  );

  runApp(MyAppLauncher());
}

class MyAppLauncher extends StatefulWidget {
  const MyAppLauncher({super.key});

  @override
  State<MyAppLauncher> createState() => _MyAppLauncherState();
}

class _MyAppLauncherState extends State<MyAppLauncher> {
  bool _showOnboarding = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    // Check if online at start, then sync
    SyncService.isOnline().then((online) {
      if (online) {
        SyncService.syncAll();
      }
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    setState(() {
      _showOnboarding = !seen;
      _loading = false;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    SyncService.isOnline().then((online) {
      if (online) {
        SyncService.syncAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return _showOnboarding
        ? MaterialApp(
            home: OnboardingScreen(onFinish: _finishOnboarding),
            debugShowCheckedModeBanner: false,
          )
        : const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Manager',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
