class OrderItem {
  final int id;
  final int orderId;
  final int productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final double lineTotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int? ?? 0,
      orderId: json['order_id'] as int? ?? 0,
      productId: json['product_id'] as int,
      productName: json['product_name'] as String? ?? '',
      productPrice: _num(json['product_price']),
      quantity: json['quantity'] as int,
      lineTotal: _num(json['line_total']),
    );
  }

  static double _num(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'quantity': quantity,
      'line_total': lineTotal,
    };
  }

  /// Body shape for POST /orders items array: {"product_id": 1, "quantity": 2}
  Map<String, dynamic> toRequestJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
    };
  }
}
