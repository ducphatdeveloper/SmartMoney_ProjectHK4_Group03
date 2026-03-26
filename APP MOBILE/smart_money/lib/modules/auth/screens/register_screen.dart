import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isHidePassword = true;
  bool isHideConfirmPassword = true;

  // Hàm tiện ích để hiển thị thông báo nhanh
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(

      body: Container(

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff1FA2FF),
              Color(0xff12D8FA),
              Color(0xffA6FFCB),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(24),

            child: Column(

              children: [

                Image.asset(
                  "assets/images/logo.png",
                  width: 150,
                  height: 150,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Create Your Account",
                  style: TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                Container(

                  padding: const EdgeInsets.all(24),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black12,
                      )
                    ],
                  ),

                  child: Column(

                      children: [

                        /// EMAIL
                        TextField(
                          controller: emailController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),

                          decoration: InputDecoration(
                            labelText: "Email (optional if phone provided)",
                            hintText: "Enter your email",

                            prefixIcon: const Icon(
                              Icons.email,
                              color: Colors.blue,
                            ),

                            filled: true,
                            fillColor: Colors.white,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white70,
                                width: 1.5,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// PHONE
                        TextField(
                          controller: phoneController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),

                          decoration: InputDecoration(
                            labelText: "Phone (optional if email provided)",
                            hintText: "Enter your phone number",

                            prefixIcon: const Icon(
                              Icons.phone,
                              color: Colors.blue,
                            ),

                            filled: true,
                            fillColor: Colors.white,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white70,
                                width: 1.5,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// PASSWORD
                        TextField(
                          controller: passwordController,
                          obscureText: isHidePassword,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),

                          decoration: InputDecoration(
                            labelText: "Password",
                            hintText: "Enter your password",

                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.blue,
                            ),

                            suffixIcon: IconButton(
                              icon: Icon(
                                isHidePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  isHidePassword = !isHidePassword;
                                });
                              },
                            ),

                            filled: true,
                            fillColor: Colors.white,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white70,
                                width: 1.5,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// CONFIRM PASSWORD
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: isHideConfirmPassword,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),

                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            hintText: "Confirm your password",

                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.blue,
                            ),

                            suffixIcon: IconButton(
                              icon: Icon(
                                isHideConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  isHideConfirmPassword = !isHideConfirmPassword;
                                });
                              },
                            ),

                            filled: true,
                            fillColor: Colors.white,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white70,
                                width: 1.5,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// REGISTER BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 50,

                          child: ElevatedButton(

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            onPressed: authProvider.isLoading
                                ? null
                                : () async {
                              final email = emailController.text.trim();
                              final phone = phoneController.text.trim();
                              final password = passwordController.text;
                              final confirmPassword = confirmPasswordController.text;

                              // 1. Kiểm tra để trống cả Email và Số điện thoại
                              if (email.isEmpty && phone.isEmpty) {
                                _showSnackBar("Vui lòng nhập ít nhất Email hoặc Số điện thoại");
                                return;
                              }

                              // 2. Kiểm tra mật khẩu trống hoặc quá ngắn
                              if (password.isEmpty) {
                                _showSnackBar("Vui lòng nhập mật khẩu");
                                return;
                              }
                              if (password.length < 6) {
                                _showSnackBar("Mật khẩu phải có ít nhất 6 ký tự");
                                return;
                              }

                              // 3. Kiểm tra mật khẩu xác nhận
                              if (password != confirmPassword) {
                                _showSnackBar("Mật khẩu xác nhận không khớp");
                                return;
                              }

                              // Gọi Provider để xử lý đăng ký
                              bool success = await authProvider.register(
                                email.isEmpty ? null : email,
                                phone.isEmpty ? null : phone,
                                password,
                                confirmPassword,
                              );

                              if (success) {
                                if (!mounted) return;
                                _showSnackBar("Đăng ký thành công! Vui lòng đăng nhập.", isError: false);
                                context.go("/login");
                              } else {
                                if (!mounted) return;
                                _showSnackBar("Đăng ký thất bại. Email hoặc Số điện thoại có thể đã tồn tại.");
                              }
                            },

                            child: authProvider.isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text(
                              "REGISTER",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// LOGIN LINK
                        TextButton(
                          onPressed: () {
                            context.go("/login");
                          },
                          child: const Text(
                            "Already have an account? Login",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      ]


                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
