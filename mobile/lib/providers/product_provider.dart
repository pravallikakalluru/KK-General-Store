import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../utils/search_matcher.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({ProductService? service})
      : _service = service ?? ProductService();

  final ProductService _service;

  List<Product> _allProducts = [];
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedCategoryId; // null = "All"
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;

  /// Full unfiltered list (used by owner screens).
  List<Product> get allProducts => _allProducts;

  /// Filtered by selected category + search query (used by customer home).
  List<Product> get filteredProducts {
    return _allProducts.where((p) {
      final matchesCategory =
          _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      final matchesSearch = SearchMatcher.matches(p, _searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> loadProducts({bool availableOnly = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allProducts = await _service.getProducts(availableOnly: availableOnly);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> createProduct({
    required String name,
    String? nameTe,
    String? searchAliases,
    required int categoryId,
    required double price,
    String? unit,
    String? description,
    bool? isAvailable,
    XFile? image,
  }) async {
    final product = await _service.createProduct(
      name: name,
      nameTe: nameTe,
      searchAliases: searchAliases,
      categoryId: categoryId,
      price: price,
      unit: unit,
      description: description,
      isAvailable: isAvailable,
      image: image,
    );
    _allProducts.insert(0, product);
    notifyListeners();
  }

  Future<void> updateProduct({
    required int id,
    String? name,
    String? nameTe,
    String? searchAliases,
    int? categoryId,
    double? price,
    String? unit,
    String? description,
    bool? isAvailable,
    XFile? image,
  }) async {
    final updated = await _service.updateProduct(
      id: id,
      name: name,
      nameTe: nameTe,
      searchAliases: searchAliases,
      categoryId: categoryId,
      price: price,
      unit: unit,
      description: description,
      isAvailable: isAvailable,
      image: image,
    );
    final index = _allProducts.indexWhere((p) => p.id == id);
    if (index != -1) {
      _allProducts[index] = updated;
    }
    notifyListeners();
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    final updated = await _service.updateAvailability(
      id: id,
      isAvailable: isAvailable,
    );
    final index = _allProducts.indexWhere((p) => p.id == id);
    if (index != -1) {
      _allProducts[index] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteProduct(int id) async {
    await _service.deleteProduct(id);
    _allProducts.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
