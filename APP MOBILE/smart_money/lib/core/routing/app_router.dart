import 'package:go_router/go_router.dart';
import '../../screens/splash_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../screens/main_navigation.dart';
import '../helpers/token_helper.dart';
import '../../modules/notification/screens/notification_screen.dart';
import '../../screens/profile_editing_screen.dart';
import '../../modules/auth/screens/reset_password_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';
import '../../modules/wallet/screens/wallet_screen.dart';
import '../../modules/category/screens/category_list_screen.dart';
import '../../modules/category/screens/category_create_screen.dart';

class AppRouter {

  static final router = GoRouter(
    initialLocation: "/",

    redirect: (context, state) async {
      if (state.matchedLocation == "/") return null;

      final accessToken = await TokenHelper.getAccessToken();
      final isLoggedIn = accessToken != null && accessToken.isNotEmpty;
      
      final isGoingToReset = state.matchedLocation == "/reset-password";
      final isGoingToForgot = state.matchedLocation == "/forgot-password";
      final isGoingToLogin = state.matchedLocation == "/login";
      final isGoingToRegister = state.matchedLocation == "/register";

      if (isGoingToReset || isGoingToForgot || isGoingToLogin || isGoingToRegister) {
        return null;
      }

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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MainNavigation(
            initialIndex: extra?['index'] ?? 0,
            timestamp: extra?['time'] ?? 0, // Nhận timestamp để trigger update
          );
        },
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
      GoRoute(
        path: '/wallets',
        builder: (context, state) => const WalletListView(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryListScreen(),
      ),
      GoRoute(
        path: '/categories/create',
        builder: (context, state) {
          final defaultType = state.extra as bool? ?? false;
          return CategoryCreateScreen(defaultCtgType: defaultType);
        },
      ),
    ],
  );

}
