// modules/auth/models/auth_response.dart
// Map đúng với AccountDto.java & AuthResponse.java của Spring Boot
// Đây là data bên trong ApiResponse<AuthResponse>

class AuthResponse {
  final int userId;
  final String? accEmail;
  final String? accPhone;
  final bool locked;
  final String? avatarUrl;
  final String? createdAt;
  final String? updatedAt;
  final String? roleName;
  final String? currencyCode;
  
  final bool isOnline;
  final String? lastActive;
  final int onlineDevicesCount;
  final List<String> onlinePlatforms;

  final String? accUsername;
  final String? fullname;
  final String? gender;
  final String? dateofbirth;
  final String? identityCard;
  final String? address;

  // JWT Tokens (Có trong AuthResponse nhưng có thể không có trong AccountDto thuần)
  final String accessToken;
  final String refreshToken;
  
  // Phân quyền bổ sung nếu cần (để app hoạt động mượt hơn)
  final String? roleCode;
  final List<String> permissions;

  AuthResponse({
    required this.userId,
    this.accEmail,
    this.accPhone,
    this.locked = false,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.roleName,
    this.currencyCode,
    this.isOnline = false,
    this.lastActive,
    this.onlineDevicesCount = 0,
    this.onlinePlatforms = const [],
    this.accUsername,
    this.fullname,
    this.gender,
    this.dateofbirth,
    this.identityCard,
    this.address,
    required this.accessToken,
    required this.refreshToken,
    this.roleCode,
    this.permissions = const [],
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Spring Boot dùng 'id' hoặc 'userId'
    final id = json['id'] ?? json['userId'] ?? 0;
    
    return AuthResponse(
      userId:       id,
      accEmail:     json['accEmail'],
      accPhone:     json['accPhone'],
      locked:       json['locked'] ?? false,
      avatarUrl:    json['avatarUrl'],
      createdAt:    json['createdAt']?.toString(),
      updatedAt:    json['updatedAt']?.toString(),
      roleName:     json['roleName'],
      currencyCode: json['currencyCode'] ?? json['currency'],
      isOnline:     json['isOnline'] ?? false,
      lastActive:   json['lastActive']?.toString(),
      onlineDevicesCount: json['onlineDevicesCount'] ?? 0,
      onlinePlatforms: json['onlinePlatforms'] != null 
          ? List<String>.from(json['onlinePlatforms']) 
          : [],
      accUsername:  json['accUsername'],
      fullname:     json['fullname'] ?? json['fullName'],
      gender:       json['gender'],
      dateofbirth:  json['dateofbirth'],
      identityCard: json['identityCard'],
      address:      json['address'],
      accessToken:  json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      roleCode:     json['roleCode'],
      permissions:  json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
    );
  }
}
