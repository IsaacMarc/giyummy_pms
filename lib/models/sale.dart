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

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        items: (json['items'] as List)
            .map((i) => SaleItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        finalTotal: (json['final_total'] as num).toDouble(),
        paymentMethod: json['payment_method'] as String,
        cashierName: json['cashier_name'] as String,
        timestamp: json['timestamp'] as String,
        status: json['status'] as String? ?? 'completed',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'discount': discount,
        'final_total': finalTotal,
        'payment_method': paymentMethod,
        'cashier_name': cashierName,
        'timestamp': timestamp,
        'status': status,
      };
}
