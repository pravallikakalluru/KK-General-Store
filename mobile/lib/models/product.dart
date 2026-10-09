class Product {
  final int id;
  final int? storeId;
  final int categoryId;
  final String name;
  final String? nameTe;
  final String? searchAliases;
  final String? description;
  final String? imageUrl;
  final double price;
  final String unit;
  final bool isAvailable;

  const Product({
    required this.id,
    this.storeId,
    required this.categoryId,
    required this.name,
    this.nameTe,
    this.searchAliases,
    this.description,
    this.imageUrl,
    required this.price,
    this.unit = 'pc',
    this.isAvailable = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      storeId: json['store_id'] as int?,
      categoryId: json['category_id'] as int,
      name: json['name'] as String,
      nameTe: json['name_te'] as String?,
      searchAliases: json['search_aliases'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      price: _parsePrice(json['price']),
      unit: json['unit'] as String? ?? 'pc',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'category_id': categoryId,
      'name': name,
      'name_te': nameTe,
      'search_aliases': searchAliases,
      'description': description,
      'image_url': imageUrl,
      'price': price,
      'unit': unit,
      'is_available': isAvailable,
    };
  }

  Product copyWith({
    int? id,
    int? storeId,
    int? categoryId,
    String? name,
    String? nameTe,
    String? searchAliases,
    String? description,
    String? imageUrl,
    double? price,
    String? unit,
    bool? isAvailable,
  }) {
    return Product(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      nameTe: nameTe ?? this.nameTe,
      searchAliases: searchAliases ?? this.searchAliases,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
