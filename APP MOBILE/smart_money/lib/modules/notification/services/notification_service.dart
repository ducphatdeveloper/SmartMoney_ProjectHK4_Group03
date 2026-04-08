import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/helpers/token_helper.dart';
import '../models/notification_response.dart';
import '../../auth/models/auth_response.dart'; // Giả định có lớp ApiResponse chung

class NotificationService {
  // Lấy header có chứa Token JWT
  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Gọi API GET /api/notifications
  Future<List<NotificationResponse>> getNotifications() async {
    final response = await http.get(
      Uri.parse(AppConstants.notificationsBase),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      // Bóc tách từ cấu trúc ApiResponse { success: true, data: [...] }
      final List<dynamic> list = data['data'];
      return list.map((json) => NotificationResponse.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load notifications: ${response.statusCode}");
    }
  }

  /// Gọi API PUT /api/notifications/{id}/read
  Future<bool> markAsRead(int id) async {
    final response = await http.put(
      Uri.parse(AppConstants.markNotificationRead(id)),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  /// Gọi API PUT /api/notifications/read-all
  Future<bool> markAllRead() async {
    final response = await http.put(
      Uri.parse(AppConstants.markAllNotificationsRead),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  /// [NEW] Gọi API PATCH /api/notifications/{id}/delivered
  /// Xác nhận thiết bị đã nhận được thông báo từ Firebase
  Future<bool> markAsDelivered(int id) async {
    final response = await http.patch(
      Uri.parse(AppConstants.markNotificationDelivered(id)),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  /// [NEW] Gọi API DELETE /api/notifications/{id}
  Future<bool> deleteNotification(int id) async {
    final response = await http.delete(
      Uri.parse(AppConstants.notificationById(id)),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }
}