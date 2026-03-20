import 'package:go_router/go_router.dart';

import '../../screens/splash_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../screens/main_navigation.dart';

class AppRouter {

  static final router = GoRouter(

    initialLocation: "/",

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
        path: "/main",
        builder: (context, state) => const MainNavigation(),
      ),

    ],

  );

}
