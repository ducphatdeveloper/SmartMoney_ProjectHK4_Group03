// modules/auth/models/register_request.dart
// Map đúng với RegisterRequest.java của Spring Boot
// Validate ở Spring Boot: phải có ít nhất accPhone HOẶC accEmail
// password và confirmPassword phải khớp nhau

class RegisterRequest {
  final String? accPhone;         // Bắt đầu bằng 0, 10-11 số
  final String? accEmail;         // Phải là email hợp lệ
  final String password;          // 6-50 ký tự
  final String confirmPassword;   // Phải khớp với password

  RegisterRequest({
    this.accPhone,
    this.accEmail,
    required this.password,
    required this.confirmPassword,
  });

  // Chuyển thành JSON để gửi lên Spring Boot
  Map<String, dynamic> toJson() {
    return {
      "accPhone":        accPhone,
      "accEmail":        accEmail,
      "password":        password,
      "confirmPassword": confirmPassword,
    };
  }

  // Validate phía client trước khi gọi API
  // Tránh gọi API khi biết chắc sẽ bị lỗi validate
  String? validate() {
    if ((accPhone == null || accPhone!.isEmpty) &&
        (accEmail == null || accEmail!.isEmpty)) {
      return "Vui lòng nhập số điện thoại hoặc email";
    }
    if (password.length < 6) {
      return "Mật khẩu phải từ 6 ký tự trở lên";
    }
    if (password != confirmPassword) {
      return "Mật khẩu xác nhận không khớp";
    }
    return null; // null = hợp lệ
  }
}