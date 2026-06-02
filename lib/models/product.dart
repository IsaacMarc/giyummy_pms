class Product {
  String id;
  String name;
  String category;
  double price;
  int stock;
  int reorderLevel;
  String status;         // <--- This is now a normal, editable variable!
  String barcode;
  String description;
  String createdAt;
  String updatedAt;
  String? expirationDate; 
  bool autoDispose;       
  String? imagePath; 

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.reorderLevel,
    this.status = 'Active', // <--- Default status is Active
    this.barcode = '',
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.expirationDate,
    this.autoDispose = false,
    this.imagePath, 
  });

  // *** DELETED THE 'String get status { ... }' BLOCK ENTIRELY ***

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(), 
      stock: json['stock'] as int,
      reorderLevel: json['reorderLevel'] as int,
      status: json['status'] as String? ?? 'Active', // <--- Loads status from database
      barcode: json['barcode'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      expirationDate: json['expirationDate'] as String?,
      autoDispose: json['autoDispose'] == 1 || json['autoDispose'] == true,
      imagePath: json['imagePath'] as String?, 
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
      'status': status, // <--- Saves 'Archived' status to database
      'barcode': barcode,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'expirationDate': expirationDate,
      'autoDispose': autoDispose ? 1 : 0, 
      'imagePath': imagePath, 
    };
  }
}