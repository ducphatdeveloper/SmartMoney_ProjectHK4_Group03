import 'package:flutter/material.dart';
import 'package:smart_money/core/di/setup_dependencies.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/routing/app_router.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/wallet/providers/wallet_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Format ngày tháng tiếng Việt
  await initializeDateFormatting('vi_VN', null);

  // Khởi tạo Firebase — bắt buộc trước khi dùng FCM
  // Nếu chưa có google-services.json thì comment dòng này lại tạm thời
  // await Firebase.initializeApp();

  // Đăng ký tất cả Service vào getIt
  setupDependencies();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: const SmartMoneyApp(),
    ),
  );
}

class SmartMoneyApp extends StatelessWidget {
  const SmartMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,

      // cấu hình GoRouter
      routerDelegate: AppRouter.router.routerDelegate,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routeInformationProvider: AppRouter.router.routeInformationProvider,

      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    );
  }
}
