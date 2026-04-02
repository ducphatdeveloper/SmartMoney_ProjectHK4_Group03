import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final usernameController = TextEditingController(text: "minh.pham@gmail.com"); // Đặt giá trị mặc định hoặc sđt 0923456789
  final passwordController = TextEditingController(text: "Test@123"); // Đặt giá trị mặc định
  bool isHidePassword = true;

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
                  "Access Your Account",
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

                        /// USERNAME
                        TextField(
                          controller: usernameController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),

                          decoration: InputDecoration(
                            labelText: "Username",
                            hintText: "Enter your username",

                            prefixIcon: const Icon(
                              Icons.person,
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

                        const SizedBox(height: 10),

                        /// FORGOT PASSWORD
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {

                              final emailController = TextEditingController();

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    title: const Text("Reset Password"),

                                    content: TextField(
                                      controller: emailController,
                                      decoration: const InputDecoration(
                                        labelText: "Enter your email",
                                        prefixIcon: Icon(Icons.email),
                                      ),
                                    ),

                                    actions: [

                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Cancel"),
                                      ),

                                      ElevatedButton(
                                        onPressed: () async {
                                          final email = emailController.text.trim();
                                          if (email.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Please enter your email")),
                                            );
                                            return;
                                          }

                                          // Gọi API gửi OTP thông qua AuthProvider
                                          final success = await authProvider.requestPasswordReset(email);

                                          if (context.mounted) {
                                            if (success) {
                                              Navigator.pop(context); // Đóng dialog
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("OTP sent to $email")),
                                              );
                                              // Chuyển sang màn hình nhập OTP và mật khẩu mới
                                              context.push('/reset-password', extra: email);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Failed to send OTP. Please try again.")),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text("Send"),
                                      ),

                                    ],
                                  );
                                },
                              );

                            },
                            child: const Text(
                              "Forgot password?",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        /// LOGIN BUTTON
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
                              bool success =
                              await authProvider.login(
                                  usernameController.text,
                                  passwordController.text);

                              if (success) {

                                if (!mounted) return;

                                context.go("/main");

                              } else {

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text("Login failed"),
                                  ),
                                );

                              }

                            },

                            child: authProvider.isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text(
                              "LOGIN",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// REGISTER LINK
                        TextButton(
                          onPressed: () {
                            context.go("/register");
                          },
                          child: const Text(
                            "Don't have an account? Register",
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
