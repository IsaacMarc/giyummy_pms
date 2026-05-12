class Product {
  final String id;
  String name;
  String category;
  double price;
  int stock;
  int reorderLevel;
  final String createdAt;
  String updatedAt;
  String barcode;
  String? expiryDate;
  String description;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.reorderLevel,
    required this.createdAt,
    required this.updatedAt,
    this.barcode = '',
    this.expiryDate,
    this.description = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        reorderLevel: json['reorder_level'] as int,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
        barcode: json['barcode'] as String? ?? '',
        expiryDate: json['expiry_date'] as String?,
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'stock': stock,
        'reorder_level': reorderLevel,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'barcode': barcode,
        'expiry_date': expiryDate,
        'description': description,
      };

  String get stockStatus {
    if (stock == 0) return 'Out of Stock';
    if (stock <= reorderLevel) return 'Low Stock';
    return 'In Stock';
  }
}
