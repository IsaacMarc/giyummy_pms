export 'user.dart';
export 'product.dart';
export 'sale.dart';
export 'alert.dart';
export 'audit_log.dart';
export 'backup.dart';

class ProductBatch {
  String id;
  String productId; // Links batch to the product
  String supplier;
  String restockReason;
  String expirationDate; // Stored as ISO8601 String
  int quantity;
  double cost;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.supplier,
    required this.restockReason,
    required this.expirationDate,
    required this.quantity,
    required this.cost,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'supplier': supplier,
      'restockReason': restockReason,
      'expirationDate': expirationDate,
      'quantity': quantity,
      'cost': cost,
    };
  }

  factory ProductBatch.fromMap(Map<String, dynamic> map) {
    return ProductBatch(
      id: map['id'],
      productId: map['productId'],
      supplier: map['supplier'],
      restockReason: map['restockReason'],
      expirationDate: map['expirationDate'],
      quantity: map['quantity'],
      cost: map['cost'],
    );
  }
}