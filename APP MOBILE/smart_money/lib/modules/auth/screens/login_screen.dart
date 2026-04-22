import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io' show Platform;
import '../providers/auth_provider.dart';
import '../../contact/screens/contact_support_screen.dart';
import '../../../core/di/setup_dependencies.dart';
import '../../../core/services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final usernameController = TextEditingController(text: "minh.pham@gmail.com"); 
  final passwordController = TextEditingController(text: "Test@123"); 
  bool isHidePassword = true;
  bool _canBiometric = false;
  bool _biometricEnabled = false;
  List<BiometricType> _availableTypes = [];

  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final authProvider = context.read<AuthProvider>();
    final biometricService = getIt<BiometricService>();
    
    final canBio = await authProvider.canUseBiometric();
    final isEnabled = await authProvider.isBiometricEnabled();
    final types = await biometricService.getAvailableBiometrics();
    
    setState(() {
      _canBiometric = canBio;
      _biometricEnabled = isEnabled;
      _availableTypes = types;
    });
  }

  Future<void> _handleBiometricLogin({bool auto = false}) async {
    final authProvider = context.read<AuthProvider>();
    // Hướng dẫn tổng hợp cho cả 2 phương thức
    String msg = 'Xác thực khuôn mặt hoặc vân tay để đăng nhập';
    
    final status = await authProvider.loginWithBiometric(context, customMessage: msg);
    
    if (!mounted) return;

    switch (status) {
      case BiometricLoginStatus.success:
        _showSnackBar('Đăng nhập sinh trắc học thành công!', isError: false);
        context.go("/main");
        break;
      case BiometricLoginStatus.authFailed:
        _showSnackBar('Xác thực sinh trắc học thất bại.');
        break;
      case BiometricLoginStatus.noCredentials:
        _showSnackBar('Vui lòng đăng nhập bằng mật khẩu để kích hoạt sinh trắc học lần đầu.');
        break;
      case BiometricLoginStatus.loginApiFailed:
        _showSnackBar(authProvider.errorMessage ?? 'Đăng nhập API thất bại.');
        break;
      default:
        if (!auto) _showSnackBar('Không thể xác thực sinh trắc học lúc này.');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Quyết định Icon hiển thị (Gộp lại)
    IconData bioIcon = Icons.fingerprint;
    if (Platform.isAndroid) {
      bioIcon = Icons.face_unlock_outlined; // Android dùng icon tổng hợp
    } else if (_availableTypes.contains(BiometricType.face)) {
      bioIcon = Icons.face; // iOS có FaceID
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff1FA2FF), Color(0xff12D8FA), Color(0xffA6FFCB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset("assets/images/logo.png", width: 150, height: 150),
                const SizedBox(height: 20),
                const Text(
                  "Access Your Account",
                  style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black12)],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: usernameController,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Username",
                          hintText: "Enter your username",
                          errorText: _usernameError,
                          prefixIcon: const Icon(Icons.person, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: isHidePassword,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Password",
                          hintText: "Enter your password",
                          errorText: _passwordError,
                          prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                          suffixIcon: IconButton(
                            icon: Icon(isHidePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => isHidePassword = !isHidePassword),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push("/forgot-password"),
                          child: const Text("Forgot password?", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () async {
                                  setState(() { _usernameError = null; _passwordError = null; });
                                  if (usernameController.text.trim().isEmpty) { _showSnackBar('Tên đăng nhập không được để trống'); return; }
                                  if (passwordController.text.trim().isEmpty) { _showSnackBar('Mật khẩu không được để trống'); return; }
                                  final success = await authProvider.login(usernameController.text, passwordController.text, context);
                                  if (!mounted) return;
                                  if (success) { context.go("/main"); }
                                  else { setState(() { _usernameError = authProvider.fieldErrors['username']; _passwordError = authProvider.fieldErrors['password']; }); _showSnackBar(authProvider.errorMessage ?? 'Có lỗi xảy ra'); }
                                },
                                child: authProvider.isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          if (_canBiometric && _biometricEnabled) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _handleBiometricLogin(auto: false),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Icon(bioIcon, size: 36, color: Colors.blue),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: authProvider.isLoading ? null : () async {
                            final success = await authProvider.loginWithGoogle(context);
                            if (!mounted) return;
                            if (success) { context.go("/main"); }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/icons/google_logo.png', height: 24),
                              const SizedBox(width: 10),
                              const Text("Sign in with Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => context.go("/register"),
                        child: const Text("Don't have an account? Register", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 10),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                        icon: const Icon(Icons.support_agent, color: Colors.orange, size: 32),
                        tooltip: "Customer Support",
                      ),
                    ],
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
