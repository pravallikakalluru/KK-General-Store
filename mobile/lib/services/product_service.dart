import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import 'api_client.dart';

/// Wraps the /products endpoints defined in API_CONTRACT.md. Create/update
/// use multipart/form-data so an optional image file can be attached.
class ProductService {
  final ApiClient _client = ApiClient();

  Future<List<Product>> getProducts({
    int? categoryId,
    String? search,
    bool availableOnly = false,
  }) async {
    final response = await _client.dio.get(
      '/products',
      queryParameters: {
        if (categoryId != null) 'category_id': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (availableOnly) 'available_only': true,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> getProduct(int id) async {
    final response = await _client.dio.get('/products/$id');
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Product> createProduct({
    required String name,
    String? nameTe,
    required int categoryId,
    required double price,
    String? unit,
    String? description,
    bool? isAvailable,
    XFile? image,
  }) async {
    final formData = await _buildFormData(
      name: name,
      nameTe: nameTe,
      categoryId: categoryId,
      price: price,
      unit: unit,
      description: description,
      isAvailable: isAvailable,
      image: image,
    );
    final response = await _client.dio.post('/products', data: formData);
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Product> updateProduct({
    required int id,
    String? name,
    String? nameTe,
    int? categoryId,
    double? price,
    String? unit,
    String? description,
    bool? isAvailable,
    XFile? image,
  }) async {
    final formData = await _buildFormData(
      name: name,
      nameTe: nameTe,
      categoryId: categoryId,
      price: price,
      unit: unit,
      description: description,
      isAvailable: isAvailable,
      image: image,
    );
    final response = await _client.dio.put('/products/$id', data: formData);
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Product> updateAvailability({
    required int id,
    required bool isAvailable,
  }) async {
    final response = await _client.dio.patch(
      '/products/$id/availability',
      data: {'is_available': isAvailable},
    );
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteProduct(int id) async {
    await _client.dio.delete('/products/$id');
  }

  Future<FormData> _buildFormData({
    String? name,
    String? nameTe,
    int? categoryId,
    double? price,
    String? unit,
    String? description,
    bool? isAvailable,
    XFile? image,
  }) async {
    final map = <String, dynamic>{
      if (name != null) 'name': name,
      if (nameTe != null) 'name_te': nameTe,
      if (categoryId != null) 'category_id': categoryId.toString(),
      if (price != null) 'price': price.toString(),
      if (unit != null) 'unit': unit,
      if (description != null) 'description': description,
      if (isAvailable != null) 'is_available': isAvailable.toString(),
    };

    if (image != null) {
      map['image'] = await MultipartFile.fromFile(
        image.path,
        filename: image.name,
      );
    }

    return FormData.fromMap(map);
  }
}
