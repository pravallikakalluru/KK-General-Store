import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({OrderService? service}) : _service = service ?? OrderService();

  final OrderService _service;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  OrderStatus? _statusFilter;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  OrderStatus? get statusFilter => _statusFilter;

  Future<void> loadOrders({OrderStatus? status}) async {
    _isLoading = true;
    _errorMessage = null;
    _statusFilter = status;
    notifyListeners();
    try {
      _orders = await _service.getOrders(status: status);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(OrderStatus? status) {
    _statusFilter = status;
    loadOrders(status: status);
  }

  Future<Order> getOrder(int id) async {
    return _service.getOrder(id);
  }

  Future<CreateOrderResult> submitOrder({
    required List<CartItem> items,
    String? notes,
  }) async {
    final result = await _service.createOrder(items: items, notes: notes);
    _orders.insert(0, result.order);
    notifyListeners();
    return result;
  }

  Future<Order> updateOrderStatus({
    required int id,
    required OrderStatus status,
  }) async {
    final updated = await _service.updateOrderStatus(id: id, status: status);
    final index = _orders.indexWhere((o) => o.id == id);
    if (index != -1) {
      _orders[index] = updated;
    }
    notifyListeners();
    return updated;
  }
}
