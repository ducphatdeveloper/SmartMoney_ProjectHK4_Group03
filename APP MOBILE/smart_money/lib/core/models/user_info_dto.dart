/// Thông tin user đầy đủ (dùng cho /api/user/me).
/// Tương ứng: UserInfoDTO.java (server)
class UserInfoDTO {
  final int id;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final int? roleId;
  final String? roleName;
  final String? roleCode;
  final Set<String> permissions;
  final String? currencyCode;
  final bool? isLocked;

  const UserInfoDTO({
    required this.id,
    this.email,
    this.phone,
    this.avatarUrl,
    this.roleId,
    this.roleName,
    this.roleCode,
    this.permissions = const {},
    this.currencyCode,
    this.isLocked,
  });

  factory UserInfoDTO.fromJson(Map<String, dynamic> json) {
    return UserInfoDTO(
      id: json['id'] as int,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      roleId: json['roleId'] as int?,
      roleName: json['roleName'] as String?,
      roleCode: json['roleCode'] as String?,
      permissions: json['permissions'] != null
          ? Set<String>.from(json['permissions'] as List)
          : {},
      currencyCode: json['currencyCode'] as String?,
      isLocked: json['isLocked'] as bool?,
    );
  }
}

