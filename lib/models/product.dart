class Product {
  String id;
  String name;
  String category;
  double price;
  int stock;
  int reorderLevel;
  String barcode;
  String description;
  String createdAt;
  String updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.reorderLevel,
    this.barcode = '',
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  // ADD THIS GETTER HERE
  String get status {
    if (stock <= 0) return 'Out of Stock';
    if (stock <= reorderLevel) return 'Low Stock';
    return 'In Stock';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      // Use num to safely parse both ints and doubles from SQLite
      price: (json['price'] as num).toDouble(), 
      stock: json['stock'] as int,
      reorderLevel: json['reorderLevel'] as int,
      barcode: json['barcode'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'reorderLevel': reorderLevel,
      'barcode': barcode,
      'description': description,
      'createdAt': createdAt, // <-- THIS WAS LIKELY MISSING
      'updatedAt': updatedAt, // <-- THIS WAS LIKELY MISSING
    };
  }
}