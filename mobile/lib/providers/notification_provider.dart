import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../services/notification_service.dart';

/// Drives the owner's unread-notification badge by polling
/// GET /notifications/unread-count every ~15s while the owner is on the
/// orders screen, per API_CONTRACT.md.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
      : _service = service ?? NotificationService();

  final NotificationService _service;
  Timer? _pollTimer;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (_) {
      // Silently ignore poll failures — not worth surfacing a snackbar for
      // a background badge refresh.
    }
  }

  void startPolling() {
    stopPolling();
    refreshUnreadCount();
    _pollTimer = Timer.periodic(
      AppConstants.notificationPollInterval,
      (_) => refreshUnreadCount(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
