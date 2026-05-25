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
  String? expirationDate; 
  bool autoDispose;       
  String? imagePath; // <--- NEW: Stores the local file path to the product image

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
    this.expirationDate,
    this.autoDispose = false,
    this.imagePath, // <--- NEW
  });

  String get status {
    if (expirationDate != null && stock > 0) {
      final exp = DateTime.parse(expirationDate!);
      if (DateTime.now().isAfter(exp)) return 'Expired';
    }
    if (stock <= 0) return 'Out of Stock';
    if (stock <= reorderLevel) return 'Low Stock';
    return 'In Stock';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(), 
      stock: json['stock'] as int,
      reorderLevel: json['reorderLevel'] as int,
      barcode: json['barcode'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      expirationDate: json['expirationDate'] as String?,
      autoDispose: json['autoDispose'] == 1 || json['autoDispose'] == true,
      imagePath: json['imagePath'] as String?, // <--- NEW
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'expirationDate': expirationDate,
      'autoDispose': autoDispose ? 1 : 0, 
      'imagePath': imagePath, // <--- NEW
    };
  }
}