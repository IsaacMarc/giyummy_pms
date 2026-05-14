import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/storage_service.dart';
import 'services/seed_data.dart';
import 'package:product_management/views/login_screen.dart';
import 'package:product_management/views/register_screen.dart';
import 'package:product_management/views/dashboard_screen.dart';
import 'package:product_management/views/sales_screen.dart';
import 'package:product_management/views/inventory_screen.dart';
import 'package:product_management/views/reports_screen.dart';
import 'package:product_management/views/alerts_screen.dart';
import 'package:product_management/views/profile_screen.dart';
import 'package:product_management/views/user_management_screen.dart';
import 'package:product_management/views/maintenance_screen.dart';
import 'package:product_management/views/help_screen.dart';
import 'widgets/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Add this import
import 'dart:io'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize desktop DB factory before anything else
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Remove the await here so runApp can execute
  await StorageService.instance.init(); 
  await seedIfNeeded();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..restoreSession(),
      child: const ProductManagementApp(),
    ),
  );
}

class ProductManagementApp extends StatelessWidget {
  const ProductManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),  
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (!provider.isLoggedIn) {
      if (provider.currentPage == 'register') {
        return const RegisterScreen();
      }
      return const LoginScreen();
    }

    final content = _pageContent(provider.currentPage, provider);

    return AppShell(child: content);
  }

  Widget _pageContent(String page, AppProvider provider) {
    switch (page) {
      case 'sales':
        return const SalesScreen();
      case 'inventory':
        return const InventoryScreen();
      case 'reports':
        return const ReportsScreen();
      case 'alerts':
        return const AlertsScreen();
      case 'profile':
        return const ProfileScreen();
      case 'users':
        if (provider.currentUser?.role == 'Admin') {
          return const UserManagementScreen();
        }
        return const DashboardScreen();
      case 'maintenance':
        return const MaintenanceScreen();
      case 'help':
        return const HelpScreen();
      default:
        return const DashboardScreen();
    }
  }
}
