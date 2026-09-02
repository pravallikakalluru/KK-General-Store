import '../models/category.dart';
import 'api_client.dart';

/// Wraps the /categories endpoints defined in API_CONTRACT.md.
class CategoryService {
  final ApiClient _client = ApiClient();

  Future<List<Category>> getCategories() async {
    final response = await _client.dio.get('/categories');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory({
    required String name,
    int? sortOrder,
  }) async {
    final response = await _client.dio.post(
      '/categories',
      data: {
        'name': name,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Category> updateCategory({
    required int id,
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _client.dio.put(
      '/categories/$id',
      data: {
        if (name != null) 'name': name,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) async {
    await _client.dio.delete('/categories/$id');
  }
}
