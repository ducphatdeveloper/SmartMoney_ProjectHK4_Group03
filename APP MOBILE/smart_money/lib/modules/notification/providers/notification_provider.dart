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
      // Gọi Service thực tế để lấy dữ liệu từ Backend
      final results = await _service.getNotifications();
      _notifications = results;
      
      _calculateUnreadCount();
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(int id) async {
    try {
      final success = await _service.markAsRead(id);
      
      if (success) {
        // Sau khi Backend cập nhật thành công, tải lại danh sách để đồng bộ UI
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

  // [NEW] Gọi khi nhận được thông báo từ FCM để báo cho backend là đã tới máy
  Future<void> markAsDelivered(int id) async {
    try {
      // Sử dụng _service thay vì _apiService
      await _service.markAsDelivered(id);

      // Sau khi báo delivered, backend set read=1 nên ta cập nhật local luôn
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        // Vì notifyRead là final, ta dùng copyWith để thay thế object trong list
        _notifications[index] = _notifications[index].copyWith(notifyRead: true);
        
        _calculateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error marking as delivered: $e");
    }
  }

  // Cập nhật hàm xóa để đảm bảo UI mượt mà
  Future<void> deleteNotification(int id) async {
    // Sao lưu danh sách cũ để revert nếu lỗi
    final oldNotifications = List<NotificationResponse>.from(_notifications);

    try {
      // Xóa ở local trước (Optimistic UI)
      _notifications.removeWhere((n) => n.id == id);
      _calculateUnreadCount();
      notifyListeners();

      // Gọi API xóa ở backend
      await _service.deleteNotification(id);
    } catch (e) {
      // Nếu lỗi thì hoàn tác lại danh sách cũ
      _notifications = oldNotifications;
      _calculateUnreadCount();
      notifyListeners();
      debugPrint("Error deleting notification: $e");
    }
  }

  /// Tính toán lại số lượng thông báo chưa đọc
  void _calculateUnreadCount() {
    _unreadCount = _notifications.where((n) => n.notifyRead != true).length;
  }

  /// Phương thức hỗ trợ cập nhật trạng thái loading
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}