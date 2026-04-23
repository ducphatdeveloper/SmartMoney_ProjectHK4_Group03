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
      return "Please enter phone number or email";
    }
    if (password.length < 6) {
      return "Password must be at least 6 characters";
    }
    if (password != confirmPassword) {
      return "Passwords do not match";
    }
    return null; // null = hợp lệ
  }
}