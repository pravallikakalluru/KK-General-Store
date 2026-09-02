class Category {
  final int id;
  final int? storeId;
  final String name;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    this.storeId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      storeId: json['store_id'] as int?,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  /// Body for POST /categories
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'sort_order': sortOrder,
    };
  }

  Category copyWith({
    int? id,
    int? storeId,
    String? name,
    int? sortOrder,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
