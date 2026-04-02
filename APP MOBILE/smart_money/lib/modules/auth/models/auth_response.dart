// modules/auth/models/auth_response.dart
// Map đúng với AuthResponse.java của Spring Boot
// Đây là data bên trong ApiResponse<AuthResponse>
// Sau khi login thành công Spring Boot trả về đầy đủ thông tin user + token

class AuthResponse {
  final int userId;
  final String? accPhone;
  final String? accUsername;
  final String? accEmail;
  final String? avatarUrl;
  final String? currency;     // VND, USD...

  // Phân quyền — dùng để ẩn/hiện tính năng Admin
  final int? roleId;
  final String? roleCode;     // ROLE_ADMIN / ROLE_USER
  final String? roleName;     // Quản trị viên / Người dùng
  final List<String> permissions; // ["USER_STANDARD_MANAGE", "ADMIN_SYSTEM_ALL"...]

  // JWT Tokens — lưu vào flutter_secure_storage
  final String accessToken;
  final String refreshToken;
  
  final String? loginAt; // Thêm trường loginAt từ JSON trả về

  AuthResponse({
    required this.userId,
    this.accPhone,
    this.accUsername,
    this.accEmail,
    this.avatarUrl,
    this.currency,
    this.roleId,
    this.roleCode,
    this.roleName,
    this.permissions = const [],
    required this.accessToken,
    required this.refreshToken,
    this.loginAt,
  });

  // Parse JSON từ Spring Boot
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId:       json['userId'],
      accPhone:     json['accPhone'],
      accUsername:  json['accUsername'],
      accEmail:     json['accEmail'],
      avatarUrl:    json['avatarUrl'],
      currency:     json['currency'],
      roleId:       json['roleId'],
      roleCode:     json['roleCode'],
      roleName:     json['roleName'],
      permissions:  json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
      accessToken:  json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      loginAt:      json['loginAt']?.toString(), // Parse loginAt
    );
  }

  // Helper check quyền — dùng trong app
  bool get isAdmin => roleCode == 'ROLE_ADMIN';
  bool get isUser  => roleCode == 'ROLE_USER';
  bool hasPermission(String perCode) => permissions.contains(perCode);
}
