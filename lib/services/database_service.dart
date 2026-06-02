import 'dart:io';
import 'package:product_management/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('giyummy_pms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // 1. Initialize FFI for Desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = join(appDir.path, 'product_management_data', filePath);

    // 2. Open the database and create tables if it doesn't exist
    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }
  Future<void> insertBatch(ProductBatch batch) async {
    final db = await database;
    await db.insert('batches', batch.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProductBatch>> getBatches() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('batches');
    return List.generate(maps.length, (i) => ProductBatch.fromMap(maps[i]));
  }

  Future _createDB(Database db, int version) async {
    // Create Users Table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        role TEXT NOT NULL,
        email TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastLogin TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        department TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');

//Create Products Table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL,
        reorderLevel INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        status TEXT DEFAULT 'Active',
        barcode TEXT NOT NULL,
        description TEXT NOT NULL,
        expirationDate TEXT,             -- NEW
        autoDispose INTEGER NOT NULL DEFAULT 0 -- NEW
      )
    ''');
//Create Audit Logs Table
    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        username TEXT NOT NULL,
        action TEXT NOT NULL,
        module TEXT NOT NULL,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

// 3. Create Sales Table
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        items TEXT NOT NULL, 
        total REAL NOT NULL,
        discount REAL NOT NULL,
        finalTotal REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        cashierName TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL      -- Notice: No comma at the end of this line!
      )
    ''');

    //Create Alerts Table
    await db.execute('''
      CREATE TABLE alerts (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        productId TEXT,
        read INTEGER NOT NULL DEFAULT 0 -- SQLite uses 1 for true, 0 for false
      )
    ''');
    // Create Backups Table
    await db.execute('''
      CREATE TABLE backups (
        id TEXT PRIMARY KEY,
        filename TEXT NOT NULL,
        size INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL      -- ADDED THIS LINE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS batches(
        id TEXT PRIMARY KEY,
        productId TEXT,
        supplier TEXT,
        restockReason TEXT,
        expirationDate TEXT,
        quantity INTEGER,
        cost REAL
      )
    ''');
  }
  
}