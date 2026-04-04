// core/models/user_model.dart
// Đại diện cho user đang đăng nhập trong toàn app
// Được tạo từ AuthResponse sau khi login thành công
// AuthProvider lưu object này vào state

import '../../modules/auth/models/auth_response.dart';

class UserModel {
  final int userId;
  final String? accPhone;
  final String? accUsername;
  final String? accEmail;
  final bool locked; // New field
  final String? avatarUrl;
  final String? currency;
  final String? createdAt; // New field
  final String? updatedAt; // New field
  final String? roleName; // Quản trị viên / Người dùng
  final String? currencyCode; // Changed from 'currency'

  final bool isOnline; // New field
  final String? lastActive; // New field
  final int onlineDevicesCount; // New field
  final List<String> onlinePlatforms; // New field

  final String? fullname;     // Tên đầy đủ (mapped from AccountDto's fullname)
  final String? gender;       // New field
  final String? dateofbirth;  // New field
  final String? identityCard; // Căn cước công dân
  final String? address;      // Địa chỉ

  // Phân quyền — dùng để ẩn/hiện tính năng Admin trong app
  final int? roleId;
  final String? roleCode;     // ROLE_ADMIN / ROLE_USER
  final List<String> permissions;

  final String? loginAt; // This was from JWT, now `lastActive` from DTO is more accurate

  UserModel({
    required this.userId,
    this.accPhone,
    this.accUsername,
    this.accEmail,
    this.locked = false,
    this.avatarUrl,
    this.currency,
    this.createdAt,
    this.updatedAt,
    this.roleName,
    this.currencyCode,
    this.isOnline = false,
    this.lastActive,
    this.onlineDevicesCount = 0,
    this.onlinePlatforms = const [],
    this.fullname,
    this.gender,
    this.dateofbirth,
    this.identityCard,
    this.address,
    this.roleId,
    this.roleCode,
    this.permissions = const [],
    this.loginAt, // Keeping for now, but `lastActive` is preferred
  });

  // Tạo UserModel từ AuthResponse sau khi login thành công
  // AuthProvider gọi hàm này: UserModel.fromAuthResponse(authResponse)
  factory UserModel.fromAuthResponse(AuthResponse response) {
    return UserModel(
      userId:      response.userId,
      accPhone:    response.accPhone,
      accUsername: response.accUsername,
      accEmail:    response.accEmail,
      locked:      response.locked,
      avatarUrl:   response.avatarUrl,
      createdAt:   response.createdAt,
      updatedAt:   response.updatedAt,
      roleName:    response.roleName,
      currencyCode: response.currencyCode,
      isOnline:    response.isOnline,
      lastActive:  response.lastActive,
      onlineDevicesCount: response.onlineDevicesCount,
      onlinePlatforms: response.onlinePlatforms,
      fullname:    response.fullname,
      gender:      response.gender,
      dateofbirth: response.dateofbirth,
      identityCard: response.identityCard,
      address:     response.address,
      roleCode:    response.roleCode, // RoleId is not in AuthResponse
      permissions: response.permissions,
      loginAt:     response.lastActive, // Using lastActive from DTO for loginAt
    );
  }

  // Add copyWith method
  UserModel copyWith({
    int? userId,
    String? accPhone,
    String? accUsername,
    String? accEmail,
    bool? locked,
    String? avatarUrl,
    String? createdAt,
    String? updatedAt,
    String? roleName,
    String? currencyCode,
    bool? isOnline,
    String? lastActive,
    int? onlineDevicesCount,
    List<String>? onlinePlatforms,
    String? fullname,
    String? gender,
    String? dateofbirth,
    String? identityCard,
    String? address,
    int? roleId,
    String? roleCode,
    List<String>? permissions,
    String? loginAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      accPhone: accPhone ?? this.accPhone,
      accUsername: accUsername ?? this.accUsername,
      accEmail: accEmail ?? this.accEmail,
      locked: locked ?? this.locked,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roleName: roleName ?? this.roleName,
      currencyCode: currencyCode ?? this.currencyCode,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
      onlineDevicesCount: onlineDevicesCount ?? this.onlineDevicesCount,
      onlinePlatforms: onlinePlatforms ?? this.onlinePlatforms,
      fullname: fullname ?? this.fullname,
      gender: gender ?? this.gender,
      dateofbirth: dateofbirth ?? this.dateofbirth,
      identityCard: identityCard ?? this.identityCard,
      address: address ?? this.address,
      roleId: roleId ?? this.roleId,
      roleCode: roleCode ?? this.roleCode,
      permissions: permissions ?? this.permissions,
      loginAt: loginAt ?? this.loginAt,
    );
  }

  // Helper check quyền — dùng trong toàn app
  bool get isAdmin => roleCode == 'ROLE_ADMIN';
  bool get isUser  => roleCode == 'ROLE_USER';
  bool hasPermission(String perCode) => permissions.contains(perCode);

  // Tên hiển thị — dùng trong UI
  // Ưu tiên fullname, fallback về username, email, rồi phone
  String get displayName => fullname ?? accUsername ?? accEmail ?? accPhone ?? "Người dùng";
}
