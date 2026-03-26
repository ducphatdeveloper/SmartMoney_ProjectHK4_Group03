import 'package:go_router/go_router.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../screens/splash_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../screens/main_navigation.dart';
import '../helpers/token_helper.dart';

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

      final isGoingToLogin = state.matchedLocation == "/login";
      final isGoingToRegister = state.matchedLocation == "/register";

      // Đang chưa login mà đòi vào trang khác -> Bắt về login
      if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister) {
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
    ],
  );

}
