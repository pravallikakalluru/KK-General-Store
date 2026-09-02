import 'enums.dart';

class User {
  final int id;
  final int? storeId;
  final String name;
  final String? email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final String? addressLine1;
  final String? town;
  final String? district;
  final String? state;
  final String? pincode;

  const User({
    required this.id,
    this.storeId,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.addressLine1,
    this.town,
    this.district,
    this.state,
    this.pincode,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      storeId: json['store_id'] as int?,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      role: UserRole.fromJson(json['role'] as String),
      isActive: json['is_active'] as bool? ?? true,
      addressLine1: json['address_line1'] as String?,
      town: json['town'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toJson(),
      'is_active': isActive,
      'address_line1': addressLine1,
      'town': town,
      'district': district,
      'state': state,
      'pincode': pincode,
    };
  }

  bool get isOwner => role == UserRole.owner;
  bool get isCustomer => role == UserRole.customer;

  String get fullAddress {
    final parts = [addressLine1, town, district, state, pincode]
        .where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }
}
