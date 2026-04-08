import 'package:go_router/go_router.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../screens/splash_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../screens/main_navigation.dart';
import '../helpers/token_helper.dart';
import '../../modules/notification/screens/notification_screen.dart';
import '../../screens/profile_editing_screen.dart';
import '../../modules/auth/screens/reset_password_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';

class AppRouter {

  static final router = GoRouter(
    initialLocation: "/",

    // Thêm tính năng redirect tổng thể
    redirect: (context, state) async {
      // Bỏ qua check redirect nếu đang ở SplashScreen (để nó tự xử lý delay/animation)
      if (state.matchedLocation == "/") return null;

      // Đọc token từ bộ nhớ
      final accessToken = await TokenHelper.getAccessToken();
      final isLoggedIn = accessToken != null && accessToken.isNotEmpty;
      final isGoingToReset = state.matchedLocation == "/reset-password";
      final isGoingToForgot = state.matchedLocation == "/forgot-password";


      final isGoingToLogin = state.matchedLocation == "/login";
      final isGoingToRegister = state.matchedLocation == "/register";

      // Đang chưa login mà đòi vào trang khác -> Bắt về login
      if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister && !isGoingToReset && !isGoingToForgot) {
        return "/login";
      }

      // Đã login rồi mà đòi vào lại trang login -> Bắt về main
      if (isLoggedIn && isGoingToLogin) {
        return "/main";
      }

      // Không rơi vào các case trên thì cứ đi tiếp bình thường
      return null;
    },

    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: "/login",
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: "/main",
        builder: (context, state) => const MainNavigation(),
      ),
      GoRoute(
        path: "/reset-password",
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: "/forgot-password",
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const ProfileEditingScreen(),
      ),
    ],
  );

}
