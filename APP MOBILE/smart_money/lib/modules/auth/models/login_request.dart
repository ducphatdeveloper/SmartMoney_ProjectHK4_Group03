// modules/auth/models/login_request.dart
// Map đúng với LoginRequest.java của Spring Boot
// Spring Boot nhận: username, password, deviceToken, deviceType, deviceName

class LoginRequest {
  final String username;      // email hoặc số điện thoại
  final String password;
  final String? deviceToken;  // FCM token — dùng cho push notification
  final String? deviceType;   // ANDROID / IOS / WEB
  final String? deviceName;   // Tên máy — hiện trong quản lý thiết bị

  LoginRequest({
    required this.username,
    required this.password,
    this.deviceToken,
    this.deviceType,
    this.deviceName,
  });

  // Chuyển thành JSON để gửi lên Spring Boot
  Map<String, dynamic> toJson() {
    return {
      "username":    username,
      "password":    password,
      "deviceToken": deviceToken ?? "",
      "deviceType":  deviceType ?? "ANDROID",
      "deviceName":  deviceName ?? "Unknown Device",
    };
  }
}