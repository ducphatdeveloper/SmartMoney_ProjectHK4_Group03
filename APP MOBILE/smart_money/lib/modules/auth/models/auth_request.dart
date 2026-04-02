class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {
        'email': email,
      };
}

class ResetPasswordRequest {
  final String email;
  final String otp;
  final String newPassword;

  ResetPasswordRequest({
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