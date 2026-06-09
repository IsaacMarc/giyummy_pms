import '../models/models.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mysql1/mysql1.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  User? _currentUser;
  MySqlConnection? _db;

  // ─── MySQL LAN Configuration ──────────────────────────────────────

  static const HOST = String.fromEnvironment('HOST', defaultValue: '127.0.0.1');
  static const PORT = int.fromEnvironment('PORT', defaultValue: 3306);
  static const DATABASE_NAME = String.fromEnvironment('DATABASE_NAME', defaultValue: 'giyummy_db');
  static const USER = String.fromEnvironment('USER', defaultValue: 'root');
  static const PASSWORD = String.fromEnvironment('PASSWORD', defaultValue: 'root');
  
  final String _host = HOST; 
  final int _port = PORT; 
  final String _user = USER;
  final String _dbName = DATABASE_NAME;

  Future<void> init() async {
    await database; // Forces the connection to establish on boot
  }

  Future<MySqlConnection> get database async {
    final settings = ConnectionSettings(
      host: _host,
      port: _port,
      user: _user,
      password: PASSWORD,
      db: _dbName,
    );

    // If we have never connected, build the first connection
    if (_db == null) {
      _db = await MySqlConnection.connect(settings);
      await _createTables(_db!); // Ensure tables exist on first connect
      return _db!;
    }

    // If we ARE connected, ping the database to see if it hung up on us
    try {
      await _db!.query('SELECT 1'); // A tiny, lightweight check
      return _db!; // It replied! Safe to use.
    } catch (e) {
      // 3. The socket was closed! Reconnect silently.
      print("⚡ Socket closed by idle timeout. Reconnecting...");
      _db = await MySqlConnection.connect(settings);
      return _db!;
    }
  }

  // ─── MySQL Helper Methods ─────────────────────────────────────────

  // Converts MySQL rows safely into Dart Maps
  Map<String, dynamic> _rowToMap(ResultRow row) {
    final map = <String, dynamic>{};
    row.fields.forEach((key, value) {
      if (value is Blob) {
        map[key] = value.toString();
      } else {
        map[key] = value;
      }
    });
    return map;
  }

  Future<void> _replaceInto(String table, Map<String, dynamic> data) async {
    final db = await database;
    final keys = data.keys.toList();
    final values = data.values.map((v) => v is bool ? (v ? 1 : 0) : v).toList();
    
    // Wrap every column name in backticks!
    final cols = keys.map((k) => '`$k`').join(', '); 
    final placeholders = List.filled(keys.length, '?').join(', ');
    
    await db.query('REPLACE INTO $table ($cols) VALUES ($placeholders)', values);
  } 

  // ─── Table Creation ───────────────────────────────────────────────

  Future<void> _createTables(MySqlConnection conn) async {
    // Users
    await conn.query('''
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        employeeId VARCHAR(50) DEFAULT '',
        firstName VARCHAR(100) DEFAULT '',
        middleInitial VARCHAR(10) DEFAULT '',
        lastName VARCHAR(100) DEFAULT '',
        username VARCHAR(255) NOT NULL,
        email VARCHAR(255) DEFAULT '',
        phone VARCHAR(50) DEFAULT '',         /* ADDED */
        passwordHash VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL,
        name VARCHAR(255) DEFAULT '',
        department VARCHAR(100) DEFAULT '',
        createdAt VARCHAR(100) DEFAULT '',
        lastLogin VARCHAR(100) DEFAULT '',
        isActive TINYINT DEFAULT 1
      )
    ''');

    // Products
    await conn.query('''
      CREATE TABLE IF NOT EXISTS products (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        category VARCHAR(100),
        price DECIMAL(10, 2),
        stock INT,
        reorderLevel INT,
        status VARCHAR(50) DEFAULT 'Active',
        barcode VARCHAR(255),
        description TEXT,
        createdAt VARCHAR(100),
        updatedAt VARCHAR(100),
        expirationDate VARCHAR(100),
        autoDispose TINYINT DEFAULT 0,
        imagePath TEXT
      )
    ''');

    // Sales
    await conn.query('''
      CREATE TABLE IF NOT EXISTS sales (
        id VARCHAR(36) PRIMARY KEY,
        items TEXT,
        total DECIMAL(10, 2),                 /* FIXED */
        discount DECIMAL(10, 2),
        finalTotal DECIMAL(10, 2),
        paymentMethod VARCHAR(50),
        cashierName VARCHAR(255),
        timestamp VARCHAR(100),
        status VARCHAR(50),                   /* ADDED */
        receiptImagePath TEXT
      )
    ''');

    // Batches
    await conn.query('''
      CREATE TABLE IF NOT EXISTS batches(
        id VARCHAR(36) PRIMARY KEY,
        productId VARCHAR(36),
        supplier VARCHAR(255),
        restockReason VARCHAR(255),
        expirationDate VARCHAR(100),
        quantity INT,
        cost DECIMAL(10, 2)
      )
    ''');

    // Alerts
    await conn.query('''
      CREATE TABLE IF NOT EXISTS alerts(
        id VARCHAR(36) PRIMARY KEY,
        type VARCHAR(100),                    /* FIXED */
        severity VARCHAR(50),                 /* ADDED */
        message TEXT,
        timestamp VARCHAR(100),
        productId VARCHAR(36),                /* ADDED */
        `read` TINYINT DEFAULT 0
      )
    ''');

    // Audit Logs
    await conn.query('''
      CREATE TABLE IF NOT EXISTS audit_logs(
        id VARCHAR(36) PRIMARY KEY,
        userId VARCHAR(36),
        username VARCHAR(255),                /* FIXED (lowercase n) */
        action VARCHAR(255),
        module VARCHAR(100),                  /* ADDED */
        details TEXT,
        timestamp VARCHAR(100)
      )
    ''');

    // Backups
    await conn.query('''
      CREATE TABLE IF NOT EXISTS backups(
        id VARCHAR(36) PRIMARY KEY,
        filename VARCHAR(255),
        size INT,                             /* FIXED */
        timestamp VARCHAR(100),
        type VARCHAR(100)                     /* ADDED */
      )
    ''');
  }

  // ─── Session Management ───────────────────────────────────────────
  void setCurrentUser(User? user) => _currentUser = user;
  User? getCurrentUser() => _currentUser;

  // ─── Users ────────────────────────────────────────────────────────
  Future<List<User>> getUsers() async {
    final db = await database;
    final result = await db.query('SELECT * FROM users');
    
    return result.map((row) {
      final map = _rowToMap(row);
      map['isActive'] = map['isActive'] == 1; // Convert TINYINT back to boolean
      return User.fromJson(map);
    }).toList();
  }

  Future<void> saveUser(User user) async {
    final map = user.toJson();
    map['isActive'] = user.isActive ? 1 : 0; 
    await _replaceInto('users', map);
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.query('DELETE FROM users WHERE id = ?', [id]);
  }

  // ─── Products ─────────────────────────────────────────────────────
  Future<List<Product>> getProducts() async {
    final db = await database;
    final result = await db.query('SELECT * FROM products');
    return result.map((row) => Product.fromJson(_rowToMap(row))).toList();
  }

  Future<void> saveProduct(Product product) async {
    await _replaceInto('products', product.toJson());
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.query('DELETE FROM products WHERE id = ?', [id]);
  }
  
  // ─── Audit Logs ───────────────────────────────────────────────────
  Future<List<AuditLog>> getAuditLogs() async {
    final db = await database;
    final result = await db.query('SELECT * FROM audit_logs ORDER BY timestamp DESC');
    return result.map((row) => AuditLog.fromJson(_rowToMap(row))).toList();
  }
  
  Future<void> saveAuditLog(AuditLog log) async {
    await _replaceInto('audit_logs', log.toJson());
  }

  // ─── Backups ──────────────────────────────────────────────────────
  Future<List<Backup>> getBackups() async {
    final db = await database;
    final result = await db.query('SELECT * FROM backups ORDER BY timestamp DESC');
    return result.map((row) => Backup.fromJson(_rowToMap(row))).toList();
  }

  Future<void> saveBackupRecord(Backup backup) async {
    await _replaceInto('backups', backup.toJson());
  }

  // Gathers data from ALL MySQL tables and packages it into a map
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    
    Future<List<Map<String, dynamic>>> fetchTable(String table) async {
      try {
        final res = await db.query('SELECT * FROM $table');
        return res.map((r) => _rowToMap(r)).toList();
      } catch (e) {
        return [];
      }
    }

    return {
      'users': await fetchTable('users'),
      'products': await fetchTable('products'),
      'batches': await fetchTable('batches'), 
      'sales': await fetchTable('sales'),
      'alerts': await fetchTable('alerts'),
      'audit_logs': await fetchTable('audit_logs'),
      'backups': await fetchTable('backups'),
    };
  }

  Future<void> saveBackupFile(String filename, Map<String, dynamic> data) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'product_management_data', 'backups'));
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final file = File(p.join(backupDir.path, filename));
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      print("Error creating backup file: $e");
    }
  }
  
  Future<void> restoreFromBackupFile(String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, 'product_management_data', 'backups', filename));
    if (!await file.exists()) throw Exception('Backup file not found on disk.');
    await restoreFromAbsolutePath(file.path);
  }

  Future<void> restoreFromAbsolutePath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Selected backup file not found.');

    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final db = await database;

    final tables = ['users', 'products', 'batches', 'sales', 'alerts', 'audit_logs', 'backups'];
    
    // MySQL Transaction Block
    await db.transaction((txn) async {
      for (final table in tables) {
        if (data.containsKey(table)) {
          await txn.query('DELETE FROM $table');
          final rows = data[table] as List;
          for (final row in rows) {
            final rowMap = Map<String, dynamic>.from(row);
            
            final keys = rowMap.keys.toList();
            final values = rowMap.values.map((v) => v is bool ? (v ? 1 : 0) : v).toList();
            final cols = keys.map((k) => '`$k`').join(', ');
            final placeholders = List.filled(keys.length, '?').join(', ');
            
            await txn.query('REPLACE INTO $table ($cols) VALUES ($placeholders)', values);
          }
        }
      }
    });
  }

  // ─── Batches ──────────────────────────────────────────────────────
  Future<List<ProductBatch>> getBatches() async {
    final db = await database;
    try {
      final result = await db.query('SELECT * FROM batches');
      return result.map((row) => ProductBatch.fromMap(_rowToMap(row))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> insertBatch(ProductBatch batch) async {
    await _replaceInto('batches', batch.toMap());
  }

  // ─── Sales ────────────────────────────────────────────────────────
  Future<List<Sale>> getSales() async {
    final db = await database;
    final result = await db.query('SELECT * FROM sales ORDER BY timestamp DESC');
    
    return result.map((row) {
      final map = _rowToMap(row);
      // Decode the stringified JSON list back into a List of dynamic objects
      if (map['items'] != null && map['items'] is String) {
        map['items'] = jsonDecode(map['items'] as String);
      }
      return Sale.fromJson(map);
    }).toList();
  }

  Future<void> saveSale(Sale sale) async {
    final map = sale.toJson();
    map['items'] = jsonEncode(map['items']); // Encode for MySQL TEXT storage
    await _replaceInto('sales', map);
  }

  Future<void> updateSale(Sale sale) async {
    final db = await database;
    final map = sale.toJson();
    map['items'] = jsonEncode(map['items']);

    final keys = map.keys.where((k) => k != 'id').toList();
    
    // Wrap every column name in backticks!
    final updates = keys.map((k) => '`$k` = ?').join(', '); 
    final values = keys.map((k) => map[k]).toList();
    values.add(sale.id); 

    await db.query('UPDATE sales SET $updates WHERE id = ?', values);
  }

  // ─── Alerts ───────────────────────────────────────────────────────
  Future<List<Alert>> getAlerts() async {
    final db = await database;
    final result = await db.query('SELECT * FROM alerts ORDER BY timestamp DESC');
    
    return result.map((row) {
      final map = _rowToMap(row);
      map['read'] = map['read'] == 1; // Convert TINYINT to Boolean
      return Alert.fromJson(map);
    }).toList();
  }

  Future<void> saveAlert(Alert alert) async {
    final map = alert.toJson();
    map['read'] = alert.read ? 1 : 0;
    await _replaceInto('alerts', map);
  }

  Future<void> deleteAlert(String id) async {
    final db = await database;
    await db.query('DELETE FROM alerts WHERE id = ?', [id]);
  }

  Future<void> clearAllAlerts() async {
    final db = await database;
    await db.query('DELETE FROM alerts'); 
  }
}