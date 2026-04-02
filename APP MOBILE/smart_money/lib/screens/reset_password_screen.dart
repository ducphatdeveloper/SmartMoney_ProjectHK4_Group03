import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/auth/providers/auth_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  void _handleReset() async {
    if (_passController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu không khớp!")),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.confirmResetPassword(
      email: widget.email,
      otp: _otpController.text,
      newPassword: _passController.text,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đổi mật khẩu thành công!")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mã OTP không đúng hoặc đã hết hạn.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Đặt lại mật khẩu"), backgroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("Nhập mã OTP gửi đến ${widget.email}", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            _buildTextField(_otpController, "Mã OTP", Icons.lock_clock),
            const SizedBox(height: 12),
            _buildTextField(_passController, "Mật khẩu mới", Icons.vpn_key, obscure: true),
            const SizedBox(height: 12),
            _buildTextField(_confirmPassController, "Xác nhận mật khẩu", Icons.vpn_key, obscure: true),
            const SizedBox(height: 30),
            Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return auth.isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Cập nhật mật khẩu"),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}