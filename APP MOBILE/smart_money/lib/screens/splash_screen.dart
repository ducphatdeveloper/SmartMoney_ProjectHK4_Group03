import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/helpers/token_helper.dart';

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

    // Kiểm tra token và chuyển hướng
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Đợi 3 giây để animation splash hoàn tất
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    // Kiểm tra quyền thông báo trước khi vào app
    await _initNotificationFlow();

    if (!mounted) return;

    final accessToken = await TokenHelper.getAccessToken();
    final isLoggedIn = accessToken != null && accessToken.isNotEmpty;

    if (isLoggedIn) {
      context.go("/main");
    } else {
      context.go("/login");
    }
  }

  /// Luồng khởi tạo thông báo chuyên nghiệp
  Future<void> _initNotificationFlow() async {
    // 1. Kiểm tra trạng thái quyền thực tế của hệ thống
    var status = await Permission.notification.status;

    if (status.isGranted) {
      return; // Đã BẬT (ON) rồi thì không cần hỏi
    }

    final prefs = await SharedPreferences.getInstance();
    // Lấy flag xem có đang yêu cầu hỏi lại (sau khi người dùng chọn "ĐỂ SAU") không
    bool hasAskedBefore = prefs.getBool('has_asked_notification_permission') ?? false;

    // Nếu chưa được cấp quyền (Denied hoặc PermanentlyDenied)
    if (!status.isGranted) {
      // Nếu là lần đầu hoặc trạng thái bị từ chối, hiện Dialog
      await _showPermissionDialog(status);
    }
  }

  /// Pop-up tùy chỉnh để giải thích và yêu cầu quyền
  Future<void> _showPermissionDialog(PermissionStatus status) async {
    if (!mounted) return;
    
    // Nếu người dùng đã từ chối vĩnh viễn (gạt nút OFF trong cài đặt)
    bool isPermanentlyDenied = status.isPermanentlyDenied;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xff1FA2FF), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPermanentlyDenied ? "Turn on notifications" : "Allow notifications",
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          isPermanentlyDenied
              ? "You currently have Smart Money notifications turned off in your settings. Please turn them on to receive important balance changes!"
              : "Allow Smart Money to send you notifications so you don't miss important balance updates and spending reminders.",
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              // Lưu false để lần sau mở app vẫn hỏi lại (để sau)
              await prefs.setBool('has_asked_notification_permission', false);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("LATER", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff1FA2FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (isPermanentlyDenied) {
                // Nếu bị tắt hẳn trong hệ thống, mở màn hình Cài đặt ứng dụng
                await openAppSettings();
              } else {
                // Gọi hộp thoại xin quyền hệ thống
                await _requestNotificationPermission();
              }
            }, 
            child: Text(isPermanentlyDenied ? "GO TO SETTINGS" : "AGREE",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  /// Hàm gọi yêu cầu quyền hệ thống
  Future<void> _requestNotificationPermission() async {
    // Popup hệ thống của Android 13+/iOS sẽ hiện ở đây
    PermissionStatus status = await Permission.notification.request();

    final prefs = await SharedPreferences.getInstance();
    if (status.isGranted) {
      await prefs.setBool('has_asked_notification_permission', true);
      debugPrint("Notification permission has been successfully granted!");
    } else {
      await prefs.setBool('has_asked_notification_permission', false);
    }
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
