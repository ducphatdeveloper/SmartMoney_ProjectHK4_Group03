import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/helpers/token_helper.dart';
import '../../../../core/models/api_response.dart';
import '../models/notification_response.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationResponse> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationResponse> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenHelper.getAccessToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse(AppConstants.notificationsBase), headers: await _getHeaders());
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final apiRes = ApiResponse<List<NotificationResponse>>.fromJson(
        data, (json) => (json as List).map((item) => NotificationResponse.fromJson(item)).toList(),
      );
      if (apiRes.success) {
        _notifications = apiRes.data ?? [];
        await fetchUnreadCount();
      }
    } catch (e) {
      debugPrint("Fetch Notifications Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await http.get(Uri.parse(AppConstants.notificationsUnreadCount), headers: await _getHeaders());
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true && data['data'] != null) {
        _unreadCount = int.tryParse(data['data'].toString()) ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Fetch Unread Count Error: $e");
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await http.put(Uri.parse(AppConstants.markNotificationRead(id)), headers: await _getHeaders());
      // Cập nhật local để UI mượt hơn
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = NotificationResponse(
          id: _notifications[index].id,
          title: _notifications[index].title,
          content: _notifications[index].content,
          notifyType: _notifications[index].notifyType,
          notifyRead: true,
          scheduledTime: _notifications[index].scheduledTime,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Mark Read Error: $e");
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> markAllAsRead() async {
    if (_unreadCount == 0) return;

    // Lưu trạng thái cũ để rollback nếu lỗi (Optimistic UI)
    final previousNotifications = List<NotificationResponse>.from(_notifications);
    final previousUnreadCount = _unreadCount;

    // Cập nhật giao diện ngay lập tức
    _unreadCount = 0;
    _notifications = _notifications.map((n) => NotificationResponse(
      id: n.id,
      title: n.title,
      content: n.content,
      notifyType: n.notifyType,
      notifyRead: true,
      scheduledTime: n.scheduledTime,
    )).toList();
    notifyListeners();

    try {
      await http.put(Uri.parse(AppConstants.markAllNotificationsRead), headers: await _getHeaders());
      // Thành công thì không cần làm gì thêm vì UI đã update
    } catch (e) {
      // Rollback nếu gọi API thất bại
      _notifications = previousNotifications;
      _unreadCount = previousUnreadCount;
      notifyListeners();
      debugPrint("Mark All Read Error: $e");
    }
  }
}