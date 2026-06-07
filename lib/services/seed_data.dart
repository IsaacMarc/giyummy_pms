import 'package:uuid/uuid.dart';
import 'package:product_management/models/models.dart';
import 'package:product_management/services/storage_service.dart';

// Make sure you have the uuid package imported at the top of your file:
  // import 'package:uuid/uuid.dart';

Future<void> seedIfNeeded() async {
  // Gets database product data
  final existingProducts = await StorageService.instance.getProducts();
  //If there are existing products, skip
  if (existingProducts.isNotEmpty) {
    return; // This return stops the rest of the function from running
  }
  
  const uuid = Uuid();
  final now = DateTime.now();
    // Generate the date strings needed for your seed data
    final todayStr = now.toIso8601String();
    final yesterdayStr = now.subtract(const Duration(days: 2)).toIso8601String();
    final nextWeekStr = now.add(const Duration(days: 5)).toIso8601String();
    final nextYearStr = now.add(const Duration(days: 365)).toIso8601String();

    final seedProducts = [
      Product(
        id: uuid.v4(),
        name: 'Shin Ramyun (5 Pack)',
        category: 'Pantry',
        price: 5.99,
        stock: 120,
        reorderLevel: 30,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801043014762',
        description: 'Spicy beef flavor instant ramen.',
        expirationDate: nextYearStr, 
        autoDispose: false,
      ),
      Product(
        id: uuid.v4(),
        name: 'Jongga Sliced Kimchi',
        category: 'Refrigerated',
        price: 7.49,
        stock: 15,
        reorderLevel: 10,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801024940348',
        description: 'Traditional fermented cabbage kimchi.',
        expirationDate: nextWeekStr, // Will trigger a "Warning: Expiring Soon" alert
        autoDispose: false,
      ),
      Product(
        id: uuid.v4(),
        name: 'Fresh Tofu (Firm)',
        category: 'Refrigerated',
        price: 2.99,
        stock: 8,
        reorderLevel: 15,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801114111221',
        description: 'Fresh firm tofu for stews.',
        expirationDate: yesterdayStr, // Expired!
        autoDispose: true,            // Will automatically dump stock to 0 on launch
      ),
      Product(
        id: uuid.v4(),
        name: 'Chung Jung One Gochujang',
        category: 'Pantry',
        price: 6.49,
        stock: 45,
        reorderLevel: 10,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801052431100',
        description: 'Korean red chili paste (500g).',
        expirationDate: nextYearStr,
        autoDispose: false,
      ),
      Product(
        id: uuid.v4(),
        name: 'Jinro Chamisul Fresh Soju',
        category: 'Beverages',
        price: 4.99,
        stock: 200,
        reorderLevel: 50,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801048161004',
        description: 'Classic Korean distilled spirit.',
        expirationDate: null, // Alcohol doesn't expire
        autoDispose: false,
      ),
      Product(
        id: uuid.v4(),
        name: 'Melona Ice Cream Bar (Melon)',
        category: 'Frozen',
        price: 1.50,
        stock: 0, // Triggers "Out of Stock" alert
        reorderLevel: 20,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801062881186',
        description: 'Melon flavored fruit milk bar.',
        expirationDate: nextYearStr,
        autoDispose: false,
      ),
      Product(
        id: uuid.v4(),
        name: 'Dongwon Tuna (Light Standard)',
        category: 'Pantry',
        price: 3.49,
        stock: 85,
        reorderLevel: 25,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801047111161',
        description: 'Canned light tuna in oil.',
        expirationDate: nextYearStr,
        autoDispose: false,
      ),
      Product(
        id: uuid.v4(),
        name: 'Orion Choco Pie',
        category: 'Snacks',
        price: 4.99,
        stock: 40,
        reorderLevel: 15,
        createdAt: todayStr,
        updatedAt: todayStr,
        barcode: '8801117132209',
        description: 'Chocolate covered marshmallow cake.',
        expirationDate: nextYearStr,
        autoDispose: false,
      ),
    ];

    // Loop through the list and push each product to MySQL!
    for (var product in seedProducts) {
      await StorageService.instance.saveProduct(product);
    }
    
    print("✅ MySQL Database successfully seeded with ${seedProducts.length} items!");
  }