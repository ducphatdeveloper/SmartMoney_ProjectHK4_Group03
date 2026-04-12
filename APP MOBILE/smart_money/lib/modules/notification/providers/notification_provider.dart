import 'package:flutter/material.dart';
import '../models/notification_response.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationResponse> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<NotificationResponse> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  /// Lấy danh sách thông báo từ API
  Future<void> fetchNotifications() async {
    _setLoading(true);

    try {
      final results = await _service.getNotifications();
      _notifications = results;
      _calculateUnreadCount();
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      // Nếu lỗi (vd: 401 Unauthorized), xóa sạch dữ liệu cục bộ
      clearNotifications();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Xóa sạch thông báo khi người dùng đăng xuất
  void clearNotifications() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(int id) async {
    try {
      final success = await _service.markAsRead(id);
      if (success) {
        await fetchNotifications(); 
      }
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  /// Đánh dấu tất cả là đã đọc
  Future<void> markAllAsRead() async {
    try {
      final success = await _service.markAllRead();
      if (success) {
        await fetchNotifications();
      }
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    }
  }

  Future<void> markAsDelivered(int id) async {
    try {
      await _service.markAsDelivered(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(notifyRead: true);
        _calculateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error marking as delivered: $e");
    }
  }

  Future<void> deleteNotification(int id) async {
    final oldNotifications = List<NotificationResponse>.from(_notifications);
    try {
      _notifications.removeWhere((n) => n.id == id);
      _calculateUnreadCount();
      notifyListeners();
      await _service.deleteNotification(id);
    } catch (e) {
      _notifications = oldNotifications;
      _calculateUnreadCount();
      notifyListeners();
      debugPrint("Error deleting notification: $e");
    }
  }

  void _calculateUnreadCount() {
    _unreadCount = _notifications.where((n) => n.notifyRead != true).length;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
