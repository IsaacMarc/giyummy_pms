import 'dart:convert';

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
import 'package:product_management/views/about_screen.dart';
import 'widgets/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 
import 'dart:io'; 


void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize desktop DB factory
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize storage and seed data
  await StorageService.instance.init(); 
  await seedIfNeeded();

  // If the app is launched with the argument 'multi_window', 
  // boot up the secondary screen instead of the main app!
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    
    // Cast the decoded JSON to a Map<String, dynamic> so it matches the expected type
    final Map<String, dynamic> argument = args[2].isEmpty ? {} : jsonDecode(args[2]);
    
    if (argument['type'] == 'customer_display') {
      // NEW: Pass the payload directly into initialData for instant loading!
      runApp(CustomerDisplayApp(
        windowId: windowId, 
        initialData: argument,
      ));
      return;
    }
  }

  // Otherwise, run the normal POS Cashier system
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
    // Using a Consumer guarantees that the MaterialApp has the correct 
    // context to listen to the AppProvider for theme changes.
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Product Management System',
          debugShowCheckedModeBanner: false,
          themeMode: provider.themeMode, // Safely reads the theme mode

          // --- LIGHT THEME ---
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            inputDecorationTheme: const InputDecorationTheme(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),  
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // --- DARK THEME ---
          // Applying the same modern shapes and Material 3 guidelines to dark mode
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            inputDecorationTheme: const InputDecorationTheme(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),  
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          home: const _AppRouter(),
        );
      },
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
      case 'about':
        return const AboutScreen();
      default:
        return const DashboardScreen();
    }
  }
}
