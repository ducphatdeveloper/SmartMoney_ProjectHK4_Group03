import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_money/core/helpers/token_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2));

    _animation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn));

    _controller.forward();

    checkLogin();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> checkLogin() async {

    final token = await TokenHelper.getAccessToken();

    // Comment dòng này lại khi dev cho nhanh
    // await Future.delayed(const Duration(seconds: 2)); // ← Bỏ khi test

    if (!mounted) return;

    if (token != null) {
      context.go("/main"); // ← Sửa từ /home thành /main
    } else {
      context.go("/login");
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff1FA2FF),
              Color(0xff12D8FA),
              Color(0xffA6FFCB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Image.asset(
                  "assets/images/logo.png",
                  width: 150,
                  height: 150,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Smart Money ",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}