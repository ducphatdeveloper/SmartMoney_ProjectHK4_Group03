import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/di/setup_dependencies.dart';
import '../../../core/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../models/reset_password_request.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;

  const ResetPasswordScreen({super.key, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = getIt<AuthService>();

  Timer? _timer;
  int _start = 60;
  bool _canResend = true;
  bool _isResending = false; // Trạng thái đang gửi lại mail

  @override
  void initState() {
    super.initState();
    
    // Lấy email từ AuthProvider nếu người dùng đã đăng nhập
    final authEmail = context.read<AuthProvider>().currentUser?.accEmail;
    
    // Ưu tiên email truyền từ widget (Forgot Password) rồi mới đến email từ Profile
    final initialEmail = widget.email ?? authEmail;

    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
      if (widget.email != null) {
        startTimer(); // Chỉ chạy timer tự động nếu đến từ luồng Quên mật khẩu
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Khởi động bộ đếm ngược
  void startTimer() {
    _timer?.cancel(); // Hủy timer cũ nếu có
    setState(() {
      _canResend = false;
      _start = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  // Xử lý gửi lại mã OTP
  Future<void> _handleResendOtp() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập Email.")),
      );
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      final response = await _authService.forgotPassword(_emailController.text.trim());

      if (context.mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Mã OTP mới đã được gửi thành công!"),
              backgroundColor: Colors.green.shade700,
            ),
          );
          startTimer(); // Chạy lại timer sau khi gửi thành công
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi kết nối server."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      
      final request = ResetPasswordRequest(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      final success = await authProvider.confirmResetPassword(email: request.email, otp: request.otp, newPassword: request.newPassword);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đặt lại mật khẩu thành công!"), backgroundColor: Colors.green),
          );
          context.go('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mã OTP sai hoặc đã hết hạn."), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Đặt lại mật khẩu"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Quên mật khẩu?",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Nhập mã OTP được gửi tới email của bạn để tiếp tục.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Email field
              _buildFieldLabel("Email đăng ký"),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? "Cần nhập email" : null,
              ),
              const SizedBox(height: 20),

              // OTP Field with Resend Button
              _buildFieldLabel("Mã xác thực OTP"),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _otpController,
                      style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
                      decoration: _inputDecoration(Icons.lock_outline),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      validator: (v) => v?.length != 6 ? "Nhập đủ 6 số" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56, // Khớp với chiều cao input
                    child: TextButton(
                      onPressed: (_canResend && !_isResending) ? _handleResendOtp : null,
                      style: TextButton.styleFrom(
                        backgroundColor: _canResend ? Colors.green.withOpacity(0.1) : Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isResending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                          : Text(
                        _canResend ? "GỬI LẠI" : "${_start}s",
                        style: TextStyle(
                          color: _canResend ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildFieldLabel("Mật khẩu mới"),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(Icons.vpn_key_outlined),
                validator: (v) => (v?.length ?? 0) < 6 ? "Tối thiểu 6 ký tự" : null,
              ),
              const SizedBox(height: 20),

              _buildFieldLabel("Xác nhận mật khẩu"),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(Icons.check_circle_outline),
                validator: (v) => v != _newPasswordController.text ? "Mật khẩu không khớp" : null,
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("XÁC NHẬN THAY ĐỔI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.green, size: 20),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      counterText: "",
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }
}
