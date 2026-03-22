/// Request đặt lại mật khẩu (sau khi có OTP).
/// Tương ứng: ResetPasswordRequest.java (server)
class ResetPasswordRequest {
  final String email;
  final String otp;
  final String newPassword;

  const ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      };
}

