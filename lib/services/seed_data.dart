import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'storage_service.dart';

Future<void> seedIfNeeded() async {
  final storage = StorageService.instance;
  final users = storage.getUsers();
  if (users.isNotEmpty) return;

  const uuid = Uuid();
  final now = DateTime.now().toIso8601String();

  final seedUsers = [
    User(
      id: uuid.v4(),
      username: 'admin',
      passwordHash: AuthService.hashPassword('admin123'),
      role: 'Admin',
      email: 'admin@company.com',
      createdAt: now,
      department: 'Management',
      phone: '+1-555-0101',
    ),
    User(
      id: uuid.v4(),
      username: 'manager',
      passwordHash: AuthService.hashPassword('manager123'),
      role: 'Manager',
      email: 'manager@company.com',
      createdAt: now,
      department: 'Operations',
      phone: '+1-555-0102',
    ),
    User(
      id: uuid.v4(),
      username: 'employee',
      passwordHash: AuthService.hashPassword('employee123'),
      role: 'Employee',
      email: 'employee@company.com',
      createdAt: now,
      department: 'Sales',
      phone: '+1-555-0103',
    ),
  ];

  final seedProducts = [
    Product(
      id: uuid.v4(),
      name: 'Laptop Pro 15',
      category: 'Electronics',
      price: 1299.99,
      stock: 45,
      reorderLevel: 10,
      createdAt: now,
      updatedAt: now,
      barcode: '1234567890',
      description: 'High-performance laptop',
    ),
    Product(
      id: uuid.v4(),
      name: 'Wireless Mouse',
      category: 'Electronics',
      price: 29.99,
      stock: 5,
      reorderLevel: 15,
      createdAt: now,
      updatedAt: now,
      barcode: '2345678901',
      description: 'Ergonomic wireless mouse',
    ),
    Product(
      id: uuid.v4(),
      name: 'Office Chair',
      category: 'Furniture',
      price: 399.99,
      stock: 12,
      reorderLevel: 5,
      createdAt: now,
      updatedAt: now,
      barcode: '3456789012',
      description: 'Ergonomic office chair',
    ),
    Product(
      id: uuid.v4(),
      name: 'Standing Desk',
      category: 'Furniture',
      price: 699.99,
      stock: 8,
      reorderLevel: 3,
      createdAt: now,
      updatedAt: now,
      barcode: '4567890123',
      description: 'Height-adjustable standing desk',
    ),
    Product(
      id: uuid.v4(),
      name: 'USB-C Hub',
      category: 'Accessories',
      price: 49.99,
      stock: 0,
      reorderLevel: 20,
      createdAt: now,
      updatedAt: now,
      barcode: '5678901234',
      description: '7-in-1 USB-C hub',
    ),
    Product(
      id: uuid.v4(),
      name: 'Monitor 27"',
      category: 'Electronics',
      price: 549.99,
      stock: 23,
      reorderLevel: 5,
      createdAt: now,
      updatedAt: now,
      barcode: '6789012345',
      description: '4K UHD monitor',
    ),
    Product(
      id: uuid.v4(),
      name: 'Desk Lamp',
      category: 'Lighting',
      price: 79.99,
      stock: 3,
      reorderLevel: 10,
      createdAt: now,
      updatedAt: now,
      barcode: '7890123456',
      description: 'LED desk lamp with USB charging',
    ),
    Product(
      id: uuid.v4(),
      name: 'Notebook Pack',
      category: 'Stationery',
      price: 12.99,
      stock: 150,
      reorderLevel: 30,
      createdAt: now,
      updatedAt: now,
      barcode: '8901234567',
      description: 'Pack of 3 ruled notebooks',
    ),
  ];

  storage.setUsers(seedUsers);
  storage.setProducts(seedProducts);
}
