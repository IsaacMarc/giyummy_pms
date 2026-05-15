class SaleItem {
  final String productId;
  final String productName;
  int quantity;
  final double price;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  double get subtotal => price * quantity;

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        quantity: json['quantity'] as int,
        price: (json['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
      };
}

class Sale {
  final String id;
  final List<SaleItem> items;
  final double total;
  final double discount;
  final double finalTotal;
  final String paymentMethod;
  final String cashierName;
  final String timestamp;
  final String status;

  Sale({
    required this.id,
    required this.items,
    required this.total,
    required this.discount,
    required this.finalTotal,
    required this.paymentMethod,
    required this.cashierName,
    required this.timestamp,
    this.status = 'completed',
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      
      // Keep your existing items parsing logic here
      items: (json['items'] as List<dynamic>)
          .map((i) => SaleItem.fromJson(i as Map<String, dynamic>))
          .toList(),
          
      total: (json['total'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      
      // THESE THREE LINES NEED TO BE UPDATED TO CAMELCASE:
      finalTotal: (json['finalTotal'] as num).toDouble(),       // Fixed from final_total
      paymentMethod: json['paymentMethod'] as String,           // Fixed from payment_method
      cashierName: json['cashierName'] as String,               // Fixed from cashier_name
      
      timestamp: json['timestamp'] as String,
      status: json['status'] as String? ?? 'completed',         // Added status
    );
  }

Map<String, dynamic> toJson() {
    return {
      'id': id,
      // Keep items exactly like this, StorageService will encode it
      'items': items.map((i) => i.toJson()).toList(), 
      'total': total,
      'discount': discount,
      'finalTotal': finalTotal,       // Fixed from final_total
      'paymentMethod': paymentMethod, // Fixed from payment_method
      'cashierName': cashierName,     // Fixed from cashier_name
      'timestamp': timestamp,
      'status': status,               // Keep this, we will add it to the DB next
    };
  }
}
