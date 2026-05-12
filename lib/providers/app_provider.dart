import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  User? _currentUser;
  String _currentPage = 'dashboard';

  User? get currentUser => _currentUser;
  String get currentPage => _currentPage;
  bool get isLoggedIn => _currentUser != null;

  // ── Navigation ──────────────────────────────────────────────────────────────

  void navigateTo(String page) {
    _currentPage = page;
    notifyListeners();
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<void> restoreSession() async {
    _currentUser = _storage.getCurrentUser();
    notifyListeners();
  }

  String? login(String username, String password) {
    final users = _storage.getUsers();
    try {
      final user = users.firstWhere(
        (u) => u.username == username && u.isActive,
      );
      if (!AuthService.verifyPassword(password, user.passwordHash)) {
        return 'Invalid username or password';
      }
      user.lastLogin = DateTime.now().toIso8601String();
      _storage.setUsers(users);
      _storage.setCurrentUser(user);
      _currentUser = user;
      _currentPage = 'dashboard';
      _addAuditLog('LOGIN', 'Auth', 'User logged in', user);
      _generateStockAlerts();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Invalid username or password';
    }
  }

  String? register(String username, String email, String password) {
    final users = _storage.getUsers();
    if (users.any((u) => u.username == username)) {
      return 'Username already exists';
    }
    final newUser = User(
      id: _uuid.v4(),
      username: username,
      passwordHash: AuthService.hashPassword(password),
      role: 'Employee',
      email: email,
      createdAt: DateTime.now().toIso8601String(),
    );
    users.add(newUser);
    _storage.setUsers(users);
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

  List<Product> getProducts() => _storage.getProducts();

  void addProduct(Product product) {
    final products = _storage.getProducts();
    products.add(product);
    _storage.setProducts(products);
    _addAuditLog('CREATE', 'Inventory', 'Added product: ${product.name}');
    notifyListeners();
  }

  void updateProduct(Product updated) {
    final products = _storage.getProducts();
    final idx = products.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      products[idx] = updated;
      _storage.setProducts(products);
      _addAuditLog('UPDATE', 'Inventory', 'Updated product: ${updated.name}');
      notifyListeners();
    }
  }

  void deleteProduct(String productId) {
    final products = _storage.getProducts();
    final product = products.firstWhere((p) => p.id == productId);
    products.removeWhere((p) => p.id == productId);
    _storage.setProducts(products);
    _addAuditLog('DELETE', 'Inventory', 'Deleted product: ${product.name}');
    notifyListeners();
  }

  // ── Sales ────────────────────────────────────────────────────────────────────

  List<Sale> getSales() => _storage.getSales();

  String? addSale(List<SaleItem> items, double discount, String paymentMethod) {
    // Validate stock
    final products = _storage.getProducts();
    for (final item in items) {
      final product = products.firstWhere((p) => p.id == item.productId);
      if (product.stock < item.quantity) {
        return 'Insufficient stock for ${item.productName}';
      }
    }

    // Deduct stock
    for (final item in items) {
      final idx = products.indexWhere((p) => p.id == item.productId);
      products[idx].stock -= item.quantity;
      products[idx].updatedAt = DateTime.now().toIso8601String();
    }
    _storage.setProducts(products);

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

    final sales = _storage.getSales();
    sales.add(sale);
    _storage.setSales(sales);

    _addAuditLog('SALE', 'Sales', 'Sale completed: \$${finalTotal.toStringAsFixed(2)}');
    _generateStockAlerts();
    notifyListeners();
    return null;
  }

  // ── Alerts ────────────────────────────────────────────────────────────────────

  List<Alert> getAlerts() {
    final alerts = _storage.getAlerts();
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  void markAlertRead(String alertId) {
    final alerts = _storage.getAlerts();
    final idx = alerts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      alerts[idx].read = true;
      _storage.setAlerts(alerts);
      notifyListeners();
    }
  }

  void markAllAlertsRead() {
    final alerts = _storage.getAlerts();
    for (final a in alerts) {
      a.read = true;
    }
    _storage.setAlerts(alerts);
    notifyListeners();
  }

  void deleteAlert(String alertId) {
    final alerts = _storage.getAlerts();
    alerts.removeWhere((a) => a.id == alertId);
    _storage.setAlerts(alerts);
    notifyListeners();
  }

  void _generateStockAlerts() {
    final products = _storage.getProducts();
    final alerts = _storage.getAlerts();
    final existingProductAlerts = alerts.map((a) => a.productId).toSet();

    for (final product in products) {
      if (existingProductAlerts.contains(product.id)) continue;
      if (product.stock == 0) {
        alerts.add(Alert(
          id: _uuid.v4(),
          type: 'low-stock',
          severity: 'critical',
          message: 'OUT OF STOCK: ${product.name} has no stock remaining.',
          timestamp: DateTime.now().toIso8601String(),
          productId: product.id,
        ));
      } else if (product.stock <= product.reorderLevel) {
        alerts.add(Alert(
          id: _uuid.v4(),
          type: 'low-stock',
          severity: 'warning',
          message:
              'LOW STOCK: ${product.name} has ${product.stock} units remaining (reorder at ${product.reorderLevel}).',
          timestamp: DateTime.now().toIso8601String(),
          productId: product.id,
        ));
      }
    }
    _storage.setAlerts(alerts);
  }

  // ── Users (Admin) ─────────────────────────────────────────────────────────────

  List<User> getUsers() => _storage.getUsers();

  void toggleUserStatus(String userId) {
    final users = _storage.getUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx >= 0) {
      users[idx].isActive = !users[idx].isActive;
      _storage.setUsers(users);
      _addAuditLog(
          'UPDATE', 'Users', 'Toggled status for: ${users[idx].username}');
      notifyListeners();
    }
  }

  void deleteUser(String userId) {
    final users = _storage.getUsers();
    final user = users.firstWhere((u) => u.id == userId);
    users.removeWhere((u) => u.id == userId);
    _storage.setUsers(users);
    _addAuditLog('DELETE', 'Users', 'Deleted user: ${user.username}');
    notifyListeners();
  }

  // ── Profile ───────────────────────────────────────────────────────────────────

  String? updateProfile({
    required String email,
    required String phone,
    required String department,
  }) {
    if (_currentUser == null) return 'Not logged in';
    final users = _storage.getUsers();
    final idx = users.indexWhere((u) => u.id == _currentUser!.id);
    if (idx < 0) return 'User not found';
    users[idx].email = email;
    users[idx].phone = phone;
    users[idx].department = department;
    _storage.setUsers(users);
    _storage.setCurrentUser(users[idx]);
    _currentUser = users[idx];
    _addAuditLog('UPDATE', 'Profile', 'Updated profile information');
    notifyListeners();
    return null;
  }

  String? changePassword(String current, String newPass) {
    if (_currentUser == null) return 'Not logged in';
    if (!AuthService.verifyPassword(current, _currentUser!.passwordHash)) {
      return 'Current password is incorrect';
    }
    final users = _storage.getUsers();
    final idx = users.indexWhere((u) => u.id == _currentUser!.id);
    if (idx < 0) return 'User not found';
    users[idx].passwordHash = AuthService.hashPassword(newPass);
    _storage.setUsers(users);
    _storage.setCurrentUser(users[idx]);
    _currentUser = users[idx];
    _addAuditLog('UPDATE', 'Profile', 'Changed password');
    notifyListeners();
    return null;
  }

  // ── Maintenance ───────────────────────────────────────────────────────────────

  List<AuditLog> getAuditLogs() {
    final logs = _storage.getAuditLogs();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs.take(50).toList();
  }

  List<Backup> getBackups() => _storage.getBackups();

  String createBackup() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final filename = 'backup_$timestamp.json';
    final data = _storage.exportAllData();
    _storage.saveBackupFile(filename, data);
    final encoded = data.toString();
    final backup = Backup(
      id: _uuid.v4(),
      filename: filename,
      size: encoded.length,
      timestamp: DateTime.now().toIso8601String(),
    );
    final backups = _storage.getBackups();
    backups.add(backup);
    _storage.setBackups(backups);
    _addAuditLog('BACKUP', 'Maintenance', 'Created backup: $filename');
    notifyListeners();
    return filename;
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  void _addAuditLog(String action, String module, String details,
      [User? user]) {
    final u = user ?? _currentUser;
    if (u == null) return;
    final logs = _storage.getAuditLogs();
    logs.add(AuditLog(
      id: _uuid.v4(),
      userId: u.id,
      username: u.username,
      action: action,
      module: module,
      details: details,
      timestamp: DateTime.now().toIso8601String(),
    ));
    _storage.setAuditLogs(logs);
  }

  void refresh() => notifyListeners();
}
