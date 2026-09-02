import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider({CategoryService? service})
      : _service = service ?? CategoryService();

  final CategoryService _service;

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _categories = await _service.getCategories();
      _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCategory({required String name, int? sortOrder}) async {
    final category =
        await _service.createCategory(name: name, sortOrder: sortOrder);
    _categories.add(category);
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> updateCategory({
    required int id,
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final updated = await _service.updateCategory(
      id: id,
      name: name,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    final index = _categories.indexWhere((c) => c.id == id);
    if (index != -1) {
      _categories[index] = updated;
    }
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await _service.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Category? byId(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
