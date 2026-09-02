import 'enums.dart';
import 'order_item.dart';

class OrderStatusHistoryEntry {
  final int id;
  final OrderStatus status;
  final DateTime changedAt;
  final int? changedByUserId;

  const OrderStatusHistoryEntry({
    required this.id,
    required this.status,
    required this.changedAt,
    this.changedByUserId,
  });

  factory OrderStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryEntry(
      id: json['id'] as int? ?? 0,
      status: OrderStatus.fromJson(json['status'] as String),
      changedAt: DateTime.parse(json['changed_at'] as String),
      changedByUserId: json['changed_by_user_id'] as int?,
    );
  }
}

class Order {
  final int id;
  final int? storeId;
  final String orderNumber;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final OrderStatus status;
  final String? notes;
  final double subtotal;
  final double totalAmount;
  final DateTime orderDate;
  final DateTime? updatedAt;
  final List<OrderItem> items;
  final List<OrderStatusHistoryEntry> statusHistory;

  const Order({
    required this.id,
    this.storeId,
    required this.orderNumber,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    this.notes,
    required this.subtotal,
    required this.totalAmount,
    required this.orderDate,
    this.updatedAt,
    this.items = const [],
    this.statusHistory = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      storeId: json['store_id'] as int?,
      orderNumber: json['order_number'] as String,
      customerId: json['customer_id'] as int?,
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      status: OrderStatus.fromJson(json['status'] as String),
      notes: json['notes'] as String?,
      subtotal: _num(json['subtotal']),
      totalAmount: _num(json['total_amount']),
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      statusHistory: (json['status_history'] as List<dynamic>?)
              ?.map((e) =>
                  OrderStatusHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
      'store_id': storeId,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'status': status.toJson(),
      'notes': notes,
      'subtotal': subtotal,
      'total_amount': totalAmount,
      'order_date': orderDate.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

/// Response envelope for POST /orders — see API_CONTRACT.md.
class CreateOrderResult {
  final Order order;
  final String whatsappMessage;
  final String whatsappUrl;

  const CreateOrderResult({
    required this.order,
    required this.whatsappMessage,
    required this.whatsappUrl,
  });

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) {
    return CreateOrderResult(
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
      whatsappMessage: json['whatsapp_message'] as String? ?? '',
      whatsappUrl: json['whatsapp_url'] as String? ?? '',
    );
  }
}
