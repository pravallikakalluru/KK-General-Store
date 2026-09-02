import '../models/cart_item.dart';
import '../models/enums.dart';
import '../models/order.dart';
import 'api_client.dart';

/// Wraps the /orders endpoints defined in API_CONTRACT.md.
class OrderService {
  final ApiClient _client = ApiClient();

  Future<CreateOrderResult> createOrder({
    required List<CartItem> items,
    String? notes,
  }) async {
    final response = await _client.dio.post(
      '/orders',
      data: {
        'items': items
            .map((c) => {
                  'product_id': c.product.id,
                  'quantity': c.quantity,
                })
            .toList(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return CreateOrderResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Order>> getOrders({OrderStatus? status}) async {
    final response = await _client.dio.get(
      '/orders',
      queryParameters: {
        if (status != null) 'status': status.toJson(),
      },
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(int id) async {
    final response = await _client.dio.get('/orders/$id');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Order> updateOrderStatus({
    required int id,
    required OrderStatus status,
  }) async {
    final response = await _client.dio.patch(
      '/orders/$id/status',
      data: {'status': status.toJson()},
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }
}
