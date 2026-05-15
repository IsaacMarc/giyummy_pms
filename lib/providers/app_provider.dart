import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:product_management/models/models.dart';
import 'package:product_management/services/auth_service.dart';
import 'package:product_management/services/storage_service.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  User? _currentUser;
  String _currentPage = 'dashboard';
  bool isInitialized = false;

  // ── IN-MEMORY CACHES (Lightning fast UI reads) ─────────────────────────────
  List<User> _users = [];
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<Alert> _alerts = [];
  List<AuditLog> _auditLogs = [];
  List<Backup> _backups = [];

  User? get currentUser => _currentUser;
  String get currentPage => _currentPage;
  bool get isLoggedIn => _currentUser != null;

  // ── Navigation ──────────────────────────────────────────────────────────────

  void navigateTo(String page) {
    _currentPage = page;
    notifyListeners();
  }

  // ── Auth & Startup ──────────────────────────────────────────────────────────

Future<void> restoreSession() async {
    // Load ALL SQLite data into RAM once at startup
    _currentUser = _storage.getCurrentUser();
    _users = await _storage.getUsers();
    _products = await _storage.getProducts();
    
    // Load the newly created SQLite tables!
    _auditLogs = await _storage.getAuditLogs();
    _backups = await _storage.getBackups();
    
    _sales = await _storage.getSales(); // Uncomment when you create the Sales table
    _alerts = await _storage.getAlerts(); // Uncomment when you create the Alerts table

    isInitialized = true;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    try {
      final user = _users.firstWhere(
        (u) => u.username == username && u.isActive,
      );
      if (!AuthService.verifyPassword(password, user.passwordHash)) {
        return 'Invalid username or password';
      }
      
      // Update memory
      user.lastLogin = DateTime.now().toIso8601String();
      _currentUser = user;
      _currentPage = 'dashboard';
      _storage.setCurrentUser(user);
      
      // Instant UI response
      notifyListeners(); 

      // Background SQLite saves
      await _storage.saveUser(user); 
      await _addAuditLog('LOGIN', 'Auth', 'User logged in', user);
      await _generateStockAlerts();
      
      return null;
    } catch (_) {
      return 'Invalid username or password';
    }
  }

  Future<String?> register(String username, String email, String password) async {
    if (_users.any((u) => u.username == username)) {
      return 'Username already exists';
    }
    
    final newUser = User(
      id: _uuid.v4(),
      username: username,
      passwordHash: AuthService.hashPassword(password),
      role: 'Employee',
      email: email,
      createdAt: DateTime.now().toIso8601String(),
      department: 'General', 
      phone: '',
      isActive: true,
    );
    
    _users.add(newUser);
    notifyListeners(); // Optimistic update
    
    await _storage.saveUser(newUser); // Save to DB
    return null;
  }

  void logout() {
    if (_currentUser != null) {
      _addAuditLog('LOGOUT', 'Auth', 'User logged out', _currentUser!);
    }
    _storage.setCurrentUser(null);
    _currentUser = null;
    _currentPage = 'dashboard';
    notifyListeners();
  }

  // ── Products ─────────────────────────────────────────────────────────────────

  List<Product> getProducts() => _products; // Instant synchronous read

  Future<void> addProduct(Product product) async {
    _products.add(product);
    notifyListeners(); // Instant UI update
    
    await _storage.saveProduct(product);
    await _addAuditLog('CREATE', 'Inventory', 'Added product: ${product.name}');
  }

  Future<void> updateProduct(Product updated) async {
    final idx = _products.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      _products[idx] = updated;
      notifyListeners(); 
      
      await _storage.saveProduct(updated);
      await _addAuditLog('UPDATE', 'Inventory', 'Updated product: ${updated.name}');
    }
  }

  Future<void> deleteProduct(String productId) async {
    final product = _products.firstWhere((p) => p.id == productId);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    
    await _storage.deleteProduct(productId);
    await _addAuditLog('DELETE', 'Inventory', 'Deleted product: ${product.name}');
  }

  // ── Sales ────────────────────────────────────────────────────────────────────

  List<Sale> getSales() => _sales;

  Future<String?> addSale(List<SaleItem> items, double discount, String paymentMethod) async {
    // 1. Validate stock in memory
    for (final item in items) {
      final product = _products.firstWhere((p) => p.id == item.productId);
      if (product.stock < item.quantity) {
        return 'Insufficient stock for ${item.productName}';
      }
    }

    // 2. Deduct stock in memory
    for (final item in items) {
      final idx = _products.indexWhere((p) => p.id == item.productId);
      _products[idx].stock -= item.quantity;
      _products[idx].updatedAt = DateTime.now().toIso8601String();
      // Background DB update
      _storage.saveProduct(_products[idx]); 
    }

    // 3. Process Sale
    final total = items.fold(0.0, (sum, i) => sum + i.subtotal);
    final discountAmount = total * discount / 100;
    final finalTotal = total - discountAmount;

    final sale = Sale(
      id: _uuid.v4(),
      items: items,
      total: total,
      discount: discountAmount,
      finalTotal: finalTotal,
      paymentMethod: paymentMethod,
      cashierName: _currentUser?.username ?? 'Unknown',
      timestamp: DateTime.now().toIso8601String(),
    );

    _sales.add(sale);
    notifyListeners(); // UI updates instantly!

    await _storage.saveSale(sale); 
    await _addAuditLog('SALE', 'Sales', 'Sale completed: \$${finalTotal.toStringAsFixed(2)}');
    await _generateStockAlerts();
    
    return null;
  }

  // ── Alerts ────────────────────────────────────────────────────────────────────

  List<Alert> getAlerts() {
    _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _alerts;
  }

  Future<void> markAlertRead(String alertId) async {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      _alerts[idx].read = true;
      notifyListeners();
      await _storage.saveAlert(_alerts[idx]); 
    }
  }

  Future<void> markAllAlertsRead() async {
    for (final a in _alerts) {
      a.read = true;
      _storage.saveAlert(a); // Save iteratively to DB
    }
    notifyListeners();
  }

  Future<void> deleteAlert(String alertId) async {
    _alerts.removeWhere((a) => a.id == alertId);
    notifyListeners();
    await _storage.deleteAlert(alertId);
  }

  Future<void> _processExpirations() async {
    bool changesMade = false;
    for (var p in _products) {
      if (p.expirationDate != null && p.stock > 0) {
        final expDate = DateTime.parse(p.expirationDate!);
        
        // If expired AND autoDispose is turned on
        if (DateTime.now().isAfter(expDate) && p.autoDispose) {
          final dumpedAmount = p.stock;
          p.stock = 0; // Dump the expired stock
          p.updatedAt = DateTime.now().toIso8601String();
          
          await _storage.saveProduct(p);
          await _addAuditLog('DISPOSE', 'Inventory', 'Auto-dumped $dumpedAmount expired units of ${p.name}');
          changesMade = true;
        }
      }
    }
    if (changesMade) notifyListeners();
  }

Future<void> _generateStockAlerts() async {
    // 1. Run the auto-dump check first
    await _processExpirations();

    final existingProductAlerts = _alerts.map((a) => a.productId).toSet();

    for (final product in _products) {
      if (existingProductAlerts.contains(product.id)) continue;
      
      Alert? newAlert;
      
      // -- NEW EXPIRATION ALERT LOGIC --
      if (product.expirationDate != null && product.stock > 0) {
        final expDate = DateTime.parse(product.expirationDate!);
        final daysUntilExp = expDate.difference(DateTime.now()).inDays;

        if (daysUntilExp < 0) {
          newAlert = Alert(
            id: _uuid.v4(),
            type: 'expired',
            severity: 'critical',
            message: 'EXPIRED: ${product.name} passed its expiration date. Please remove from shelves.',
            timestamp: DateTime.now().toIso8601String(),
            productId: product.id,
          );
        } else if (daysUntilExp <= 7) {
          newAlert = Alert(
            id: _uuid.v4(),
            type: 'expiring-soon',
            severity: 'warning',
            message: 'EXPIRING SOON: ${product.name} expires in $daysUntilExp days.',
            timestamp: DateTime.now().toIso8601String(),
            productId: product.id,
          );
        }
      }

      // -- EXISTING STOCK ALERT LOGIC --
      if (newAlert == null) {
        if (product.stock == 0) {
          newAlert = Alert(
            id: _uuid.v4(),
            type: 'low-stock',
            severity: 'critical',
            message: 'OUT OF STOCK: ${product.name} has no stock remaining.',
            timestamp: DateTime.now().toIso8601String(),
            productId: product.id,
          );
        } else if (product.stock <= product.reorderLevel) {
          newAlert = Alert(
            id: _uuid.v4(),
            type: 'low-stock',
            severity: 'warning',
            message: 'LOW STOCK: ${product.name} has ${product.stock} units remaining.',
            timestamp: DateTime.now().toIso8601String(),
            productId: product.id,
          );
        }
      }

      if (newAlert != null) {
        _alerts.add(newAlert);
        await _storage.saveAlert(newAlert);
      }
    }
    notifyListeners();
  }

  // ── Users (Admin) ─────────────────────────────────────────────────────────────

  List<User> getUsers() => _users;

  Future<void> toggleUserStatus(String userId) async {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx >= 0) {
      _users[idx].isActive = !_users[idx].isActive;
      notifyListeners();
      
      await _storage.saveUser(_users[idx]);
      await _addAuditLog('UPDATE', 'Users', 'Toggled status for: ${_users[idx].username}');
    }
  }

  Future<void> deleteUser(String userId) async {
    final user = _users.firstWhere((u) => u.id == userId);
    _users.removeWhere((u) => u.id == userId);
    notifyListeners();
    
    await _storage.deleteUser(userId);
    await _addAuditLog('DELETE', 'Users', 'Deleted user: ${user.username}');
  }

  // ── Profile ───────────────────────────────────────────────────────────────────

  Future<String?> updateProfile({required String email, required String phone, required String department}) async {
    if (_currentUser == null) return 'Not logged in';
    final idx = _users.indexWhere((u) => u.id == _currentUser!.id);
    if (idx < 0) return 'User not found';
    
    _users[idx].email = email;
    _users[idx].phone = phone;
    _users[idx].department = department;
    _currentUser = _users[idx];
    
    notifyListeners();
    
    await _storage.saveUser(_users[idx]);
    _storage.setCurrentUser(_users[idx]);
    await _addAuditLog('UPDATE', 'Profile', 'Updated profile information');
    return null;
  }

  // ADD THIS MISSING METHOD HERE:
  Future<String?> changePassword(String current, String newPass) async {
    if (_currentUser == null) return 'Not logged in';
    
    // Verify the current password
    if (!AuthService.verifyPassword(current, _currentUser!.passwordHash)) {
      return 'Current password is incorrect';
    }
    
    final idx = _users.indexWhere((u) => u.id == _currentUser!.id);
    if (idx < 0) return 'User not found';
    
    // Update the password hash in memory
    _users[idx].passwordHash = AuthService.hashPassword(newPass);
    _currentUser = _users[idx];
    
    notifyListeners(); // Update UI
    
    // Save to SQLite database in the background
    await _storage.saveUser(_users[idx]);
    _storage.setCurrentUser(_users[idx]);
    await _addAuditLog('UPDATE', 'Profile', 'Changed password');
    
    return null;
  }
  // ── Internal ─────────────────────────────────────────────────────────────────

  Future<void> _addAuditLog(String action, String module, String details, [User? user]) async {
    final u = user ?? _currentUser;
    if (u == null) return;
    
    final log = AuditLog(
      id: _uuid.v4(),
      userId: u.id,
      username: u.username,
      action: action,
      module: module,
      details: details,
      timestamp: DateTime.now().toIso8601String(),
    );
    
    _auditLogs.add(log);
    // await _storage.saveAuditLog(log);
  }

  Future<String> createBackup() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final filename = 'backup_$timestamp.json';
    
    // 1. Await the data export
    final data = await _storage.exportAllData();
    
    // 2. Await saving the physical file
    await _storage.saveBackupFile(filename, data);
    
    final encoded = jsonEncode(data); // Use jsonEncode to accurately measure size
    
    final backup = Backup(
      id: _uuid.v4(),
      filename: filename,
      size: encoded.length,
      timestamp: DateTime.now().toIso8601String(),
    );
    
    _backups.add(backup);
    notifyListeners();
    
    // 3. Save the backup record to the SQLite database
    await _storage.saveBackupRecord(backup);
    await _addAuditLog('BACKUP', 'Maintenance', 'Created backup: $filename');
    
    return filename;
  }

  // ── Maintenance & Logs ────────────────────────────────────────────────────────

  List<AuditLog> getAuditLogs() {
    // Sort so the newest logs are always at the top
    _auditLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _auditLogs.take(50).toList(); // Only show the latest 50 in the UI
  }

  List<Backup> getBackups() {
    _backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _backups;
  }


  void refresh() => notifyListeners();
}