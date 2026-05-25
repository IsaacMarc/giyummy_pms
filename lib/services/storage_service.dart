import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  User? _currentUser;

  // We no longer need the complex Directory init() here because 
  // DatabaseService handles it.
  Future<void> init() async {
    await DatabaseService.instance.database;
  }

  // Session Management (Still kept in memory for quick access)
  void setCurrentUser(User? user) => _currentUser = user;
  User? getCurrentUser() => _currentUser;

  // ─── Users ────────────────────────────────────────────────────────

  Future<List<User>> getUsers() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('users');
    
    // Convert SQLite 1/0 integers back to Dart booleans
    return result.map((json) {
      final map = Map<String, dynamic>.from(json);
      map['isActive'] = map['isActive'] == 1;
      return User.fromJson(map);
    }).toList();
  }

  Future<void> saveUser(User user) async {
    final db = await DatabaseService.instance.database;
    final map = user.toJson();
    map['isActive'] = user.isActive ? 1 : 0; // SQLite doesn't have booleans

    await db.insert(
      'users',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace, // Updates if ID exists
    );
  }

  Future<void> deleteUser(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Products ─────────────────────────────────────────────────────

  Future<List<Product>> getProducts() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromJson(json)).toList();
  }

  Future<void> saveProduct(Product product) async {
      final db = await DatabaseService.instance.database;
      
      try {
        await db.execute("ALTER TABLE products ADD COLUMN imagePath TEXT");
      } catch (_) {
      }
      
      await db.insert(
        'products',
        product.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

  Future<void> deleteProduct(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
  
  // ─── Audit Logs ───────────────────────────────────────────────────

  Future<List<AuditLog>> getAuditLogs() async {
    final db = await DatabaseService.instance.database;
    // Get logs, automatically sorted by newest first
    final result = await db.query('audit_logs', orderBy: 'timestamp DESC');
    return result.map((json) => AuditLog.fromJson(json)).toList();
  }

  Future<void> saveAuditLog(AuditLog log) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'audit_logs',
      log.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Backups ──────────────────────────────────────────────────────

  Future<List<Backup>> getBackups() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('backups', orderBy: 'timestamp DESC');
    return result.map((json) => Backup.fromJson(json)).toList();
  }

  Future<void> saveBackupRecord(Backup backup) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'backups',
      backup.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Export Logic for Backups ─────────────────────────────────────

  // Gathers data from ALL SQLite tables and packages it into a map
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await DatabaseService.instance.database;
    return {
      'users': await db.query('users'),
      'products': await db.query('products'),
      'sales': await db.query('sales'),
      'alerts': await db.query('alerts'),
      'audit_logs': await db.query('audit_logs'),
      'backups': await db.query('backups'),
    };
  }

  // Writes the exported map to a physical JSON file on the computer
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
  
  //Restores from the internal backups folder ---
  Future<void> restoreFromBackupFile(String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, 'product_management_data', 'backups', filename));

    if (!await file.exists()) throw Exception('Backup file not found on disk.');

    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final tables = ['users', 'products', 'sales', 'alerts', 'audit_logs', 'backups'];
      
      for (final table in tables) {
        if (data.containsKey(table)) {
          await txn.delete(table);
          final rows = data[table] as List;
          for (final row in rows) {
            await txn.insert(table, Map<String, dynamic>.from(row));
          }
        }
      }
    });
  }

  // NEW: Reads a JSON file from ANY folder on the computer
  Future<void> restoreFromAbsolutePath(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) throw Exception('Selected backup file not found.');

    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final tables = ['users', 'products', 'sales', 'alerts', 'audit_logs', 'backups'];
      
      for (final table in tables) {
        if (data.containsKey(table)) {
          await txn.delete(table);
          final rows = data[table] as List;
          for (final row in rows) {
            await txn.insert(table, Map<String, dynamic>.from(row));
          }
        }
      }
    });
  }

  // ─── Sales ────────────────────────────────────────────────────────

  Future<List<Sale>> getSales() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('sales', orderBy: 'timestamp DESC');
    
    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      // Decode the stringified JSON list back into a List of dynamic objects
      map['items'] = jsonDecode(map['items'] as String);
      return Sale.fromJson(map);
    }).toList();
  }

 Future<void> saveSale(Sale sale) async {
    final db = await DatabaseService.instance.database;
    
    // --- FIX: Add the column safely before trying to insert a new sale! ---
    try {
      await db.execute("ALTER TABLE sales ADD COLUMN receiptImagePath TEXT");
    } catch (_) {
      // Ignore if the column already exists
    }

    final map = sale.toJson();
    
    // Encode the List of items into a flat JSON string for SQLite storage
    map['items'] = jsonEncode(map['items']);

    await db.insert(
      'sales',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- NEW: Update an existing sale (used for attaching receipts) ---
  Future<void> updateSale(Sale sale) async {
    final db = await DatabaseService.instance.database;
    
    // Safely attempt to inject the new column into the existing database
    try {
      await db.execute("ALTER TABLE sales ADD COLUMN receiptImagePath TEXT");
    } catch (_) {
      // Ignore if the column already exists
    }

    final map = sale.toJson();
    // Re-encode the items list to a JSON string just like we do in saveSale
    map['items'] = jsonEncode(map['items']);

    await db.update('sales', map, where: 'id = ?', whereArgs: [sale.id]);
  }

  // ─── Alerts ───────────────────────────────────────────────────────

  Future<List<Alert>> getAlerts() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('alerts', orderBy: 'timestamp DESC');
    
    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      // Convert SQLite integer back to Dart boolean
      map['read'] = map['read'] == 1;
      return Alert.fromJson(map);
    }).toList();
  }

  Future<void> saveAlert(Alert alert) async {
    final db = await DatabaseService.instance.database;
    final map = alert.toJson();
    
    // Convert Dart boolean to SQLite integer
    map['read'] = alert.read ? 1 : 0;

    await db.insert(
      'alerts',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAlert(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllAlerts() async {
    final db = await DatabaseService.instance.database;
    await db.delete('alerts'); // Deletes all rows in the alerts table
  }

}