import 'api_client.dart';

/// Wraps the /notifications endpoints (owner only) defined in
/// API_CONTRACT.md.
class NotificationService {
  final ApiClient _client = ApiClient();

  Future<int> getUnreadCount() async {
    final response = await _client.dio.get('/notifications/unread-count');
    final data = response.data as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  Future<void> markRead(int id) async {
    await _client.dio.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.dio.post('/notifications/read-all');
  }
}
