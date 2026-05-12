import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:product_management/models/models.dart';

class StorageService {
  static StorageService? _instance;
  late Directory _dataDir;
  bool _initialized = false;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // This is where it was hanging
      final appDir = await getApplicationDocumentsDirectory(); 
      _dataDir = Directory('${appDir.path}/product_management_data');
      
      if (!_dataDir.existsSync()) {
        _dataDir.createSync(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint("Storage initialization failed: $e");
    }
  }

  File _file(String name) {
  // If not initialized yet, point to a temporary location or throw error
  if (!_initialized) {
     throw Exception("StorageService not initialized");
  }
  return File('${_dataDir.path}/$name.json');
  }

  List<dynamic> _readList(String name) {
    final f = _file(name);
    if (!f.existsSync()) return [];
    try {
      return jsonDecode(f.readAsStringSync()) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _readMap(String name) {
    final f = _file(name);
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _writeList(String name, List<dynamic> data) {
    _file(name).writeAsStringSync(jsonEncode(data));
  }

  void _writeMap(String name, Map<String, dynamic>? data) {
    if (data == null) {
      final f = _file(name);
      if (f.existsSync()) f.deleteSync();
    } else {
      _file(name).writeAsStringSync(jsonEncode(data));
    }
  }

  // Users
  List<User> getUsers() =>
      _readList('users').map((e) => User.fromJson(e as Map<String, dynamic>)).toList();

  void setUsers(List<User> users) =>
      _writeList('users', users.map((u) => u.toJson()).toList());

  // Products
  List<Product> getProducts() =>
      _readList('products').map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();

  void setProducts(List<Product> products) =>
      _writeList('products', products.map((p) => p.toJson()).toList());

  // Sales
  List<Sale> getSales() =>
      _readList('sales').map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();

  void setSales(List<Sale> sales) =>
      _writeList('sales', sales.map((s) => s.toJson()).toList());

  // Alerts
  List<Alert> getAlerts() =>
      _readList('alerts').map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList();

  void setAlerts(List<Alert> alerts) =>
      _writeList('alerts', alerts.map((a) => a.toJson()).toList());

  // Audit Logs
  List<AuditLog> getAuditLogs() =>
      _readList('audit_logs').map((e) => AuditLog.fromJson(e as Map<String, dynamic>)).toList();

  void setAuditLogs(List<AuditLog> logs) =>
      _writeList('audit_logs', logs.map((l) => l.toJson()).toList());

  // Backups
  List<Backup> getBackups() =>
      _readList('backups').map((e) => Backup.fromJson(e as Map<String, dynamic>)).toList();

  void setBackups(List<Backup> backups) =>
      _writeList('backups', backups.map((b) => b.toJson()).toList());

  // Current user session
  User? getCurrentUser() {
    final data = _readMap('current_user');
    if (data == null) return null;
    return User.fromJson(data);
  }

  void setCurrentUser(User? user) => _writeMap('current_user', user?.toJson());

  // Raw backup export
  String get dataDirectoryPath => _dataDir.path;

  Map<String, dynamic> exportAllData() => {
        'users': getUsers().map((u) => u.toJson()).toList(),
        'products': getProducts().map((p) => p.toJson()).toList(),
        'sales': getSales().map((s) => s.toJson()).toList(),
        'alerts': getAlerts().map((a) => a.toJson()).toList(),
        'audit_logs': getAuditLogs().map((l) => l.toJson()).toList(),
      };

  void saveBackupFile(String filename, Map<String, dynamic> data) {
    final file = File('${_dataDir.path}/$filename');
    file.writeAsStringSync(jsonEncode(data));
  }
}
