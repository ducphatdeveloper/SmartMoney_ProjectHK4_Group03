import 'package:flutter/material.dart';
import 'package:smart_money/core/di/setup_dependencies.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routing/app_router.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/budget/providers/budget_provider.dart';
import 'firebase_options.dart'; // Import file cấu hình Firebase
import 'modules/wallet/providers/wallet_provider.dart';
import 'modules/transaction/providers/transaction_provider.dart';
import 'modules/category/providers/category_provider.dart';
import 'modules/planned/providers/recurring_provider.dart';
import 'modules/planned/providers/bill_provider.dart';
import 'modules/planned/providers/bill_transaction_provider.dart'; // Import mới
import 'package:smart_money/modules/event/providers/event_provider.dart';
import 'package:smart_money/modules/saving_goal/providers/saving_goal_provider.dart';
import 'modules/debt/providers/debt_provider.dart';
import 'package:smart_money/modules/notification/providers/notification_provider.dart';
import 'package:smart_money/modules/contact/providers/contact_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Format ngày tháng tiếng Việt
  await initializeDateFormatting('vi_VN', null);

  // Khởi tạo Firebase — bắt buộc trước khi dùng FCM
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // Đăng ký tất cả Service vào getIt
  setupDependencies();

  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => BillTransactionProvider()), // Đăng ký BillTransactionProvider
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => SavingGoalProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
      ],
      child: const SmartMoneyApp(),
    );
  }
}







class SmartMoneyApp extends StatefulWidget {
  const SmartMoneyApp({super.key});

  @override
  State<SmartMoneyApp> createState() => _SmartMoneyAppState();
}

class _SmartMoneyAppState extends State<SmartMoneyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _setupFCM() {
    // Xử lý khi nhận thông báo ở Foreground (App đang mở)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Nhận thông báo mới: ${message.notification?.title}");

      // 1. Lấy ID thông báo từ data payload của Firebase
      final notifyIdStr = message.data['id'];
      if (notifyIdStr != null) {
        try {
          int notifyId = int.parse(notifyIdStr);

          // 2. Gọi API báo đã nhận (để backend set read = 1 và sent = 1)
          // Sử dụng context của State để truy cập Provider
          if (mounted) {
            context.read<NotificationProvider>().markAsDelivered(notifyId);
          }
        } catch (e) {
          debugPrint("Lỗi parse notifyId: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,

      // Bắt buộc để DatePicker hiển thị tiếng Việt (tháng, thứ, nút OK/HỦY)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),  // Tiếng Việt
        Locale('en', 'US'),  // English
      ],

      // cấu hình GoRouter
      routerDelegate: AppRouter.router.routerDelegate,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routeInformationProvider: AppRouter.router.routeInformationProvider,

      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    );
  }
}
