// core/models/user_model.dart
// Đại diện cho user đang đăng nhập trong toàn app
// Được tạo từ AuthResponse sau khi login thành công
// AuthProvider lưu object này vào state

import '../../modules/auth/models/auth_response.dart';

class UserModel {
  final int userId;
  final String? accPhone;
  final String? accEmail;
  final String? avatarUrl;
  final String? currency;     // VND, USD...

  // Phân quyền — dùng để ẩn/hiện tính năng Admin trong app
  final int? roleId;
  final String? roleCode;     // ROLE_ADMIN / ROLE_USER
  final String? roleName;     // Quản trị viên / Người dùng
  final List<String> permissions;
  
  final String? loginAt; // Thêm trường loginAt

  UserModel({
    required this.userId,
    this.accPhone,
    this.accEmail,
    this.avatarUrl,
    this.currency,
    this.roleId,
    this.roleCode,
    this.roleName,
    this.permissions = const [],
    this.loginAt,
  });

  // Tạo UserModel từ AuthResponse sau khi login thành công
  // AuthProvider gọi hàm này: UserModel.fromAuthResponse(authResponse)
  factory UserModel.fromAuthResponse(AuthResponse response) {
    return UserModel(
      userId:      response.userId,
      accPhone:    response.accPhone,
      accEmail:    response.accEmail,
      avatarUrl:   response.avatarUrl,
      currency:    response.currency,
      roleId:      response.roleId,
      roleCode:    response.roleCode,
      roleName:    response.roleName,
      permissions: response.permissions,
      loginAt:     response.loginAt, // Map trường loginAt
    );
  }

  // Helper check quyền — dùng trong toàn app
  bool get isAdmin => roleCode == 'ROLE_ADMIN';
  bool get isUser  => roleCode == 'ROLE_USER';
  bool hasPermission(String perCode) => permissions.contains(perCode);

  // Tên hiển thị — dùng trong UI
  // Ưu tiên email, fallback về phone
  String get displayName => accEmail ?? accPhone ?? "Người dùng";
}
