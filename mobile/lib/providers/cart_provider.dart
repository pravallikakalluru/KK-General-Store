import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// In-memory cart — ephemeral per session, as specified (no local
/// persistence required).
class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  String _notes = '';

  List<CartItem> get items => _items.values.toList(growable: false);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  String get notes => _notes;

  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.lineTotal);

  int quantityOf(int productId) => _items[productId]?.quantity ?? 0;

  bool contains(int productId) => _items.containsKey(productId);

  void addProduct(Product product, {int quantity = 1}) {
    if (!product.isAvailable) return;
    final existing = _items[product.id];
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void incrementQuantity(int productId) {
    final item = _items[productId];
    if (item == null) return;
    item.quantity += 1;
    notifyListeners();
  }

  void decrementQuantity(int productId) {
    final item = _items[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(productId);
    } else {
      item.quantity -= 1;
    }
    notifyListeners();
  }

  void setQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      final item = _items[productId];
      if (item != null) {
        item.quantity = quantity;
      }
    }
    notifyListeners();
  }

  void removeProduct(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _notes = '';
    notifyListeners();
  }
}
