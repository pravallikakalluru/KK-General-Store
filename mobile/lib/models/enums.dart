/// Enums shared with the backend — string values MUST match
/// API_CONTRACT.md exactly (they are sent/received as raw JSON strings).

enum UserRole {
  owner,
  customer,
  employee;

  static UserRole fromJson(String value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'customer':
        return UserRole.customer;
      case 'employee':
        return UserRole.employee;
      default:
        throw ArgumentError('Unknown UserRole: $value');
    }
  }

  String toJson() => name;
}

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  completed,
  cancelled;

  static OrderStatus fromJson(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        throw ArgumentError('Unknown OrderStatus: $value');
    }
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;
}
