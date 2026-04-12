import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

    // Chuyển hướng sau khi animation kết thúc
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.go("/main"); // Luôn vào trang main bất kể đăng nhập hay chưa
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
