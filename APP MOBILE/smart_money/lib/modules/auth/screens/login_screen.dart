import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../contact/screens/contact_support_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final usernameController = TextEditingController(text: "minh.pham@gmail.com"); // Đặt giá trị mặc định hoặc sđt 0923456789
  final passwordController = TextEditingController(text: "Test@123"); // Đặt giá trị mặc định
  bool isHidePassword = true;

  String? _usernameError;
  String? _passwordError;

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
                            errorText: _usernameError,

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
                            errorText: _passwordError,

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
                              context.push("/forgot-password");
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
                              
                              setState(() {
                                _usernameError = null;
                                _passwordError = null;
                              });

                              final errors = await authProvider.login(
                                  usernameController.text,
                                  passwordController.text);

                              if (errors == null) {
                                if (!mounted) return;
                                context.go("/main");
                              } else {
                                if (!mounted) return;
                                setState(() {
                                  _usernameError = errors['username'];
                                  _passwordError = errors['password'];
                                });

                                if (errors.containsKey('general')) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errors['general']!)),
                                  );
                                } else if (_usernameError == null && _passwordError == null) {
                                  // Trường hợp lỗi chung từ backend (VD: 401 Bad Credentials)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Invalid username or password")),
                                  );
                                }
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

                        const SizedBox(height: 10),

                        /// SUPPORT ICON
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
                            );
                          },
                          icon: const Icon(
                            Icons.support_agent,
                            color: Colors.orange,
                            size: 32,
                          ),
                          tooltip: "Customer Support",
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
