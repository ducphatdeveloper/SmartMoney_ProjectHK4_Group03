import 'package:flutter/material.dart';
import 'package:smart_money/core/di/setup_dependencies.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routing/app_router.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/budget/providers/budget_provider.dart';
import 'firebase_options.dart'; 
import 'modules/wallet/providers/wallet_provider.dart';
import 'modules/transaction/providers/transaction_provider.dart';
import 'modules/category/providers/category_provider.dart';
import 'modules/planned/providers/recurring_provider.dart';
import 'modules/planned/providers/bill_provider.dart';
import 'modules/planned/providers/bill_transaction_provider.dart';
import 'package:smart_money/modules/event/providers/event_provider.dart';
import 'package:smart_money/modules/saving_goal/providers/saving_goal_provider.dart';
import 'modules/debt/providers/debt_provider.dart';
import 'package:smart_money/modules/notification/providers/notification_provider.dart';
import 'package:smart_money/modules/contact/providers/contact_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- CẤU HÌNH THÔNG BÁO CỤC BỘ (LOCAL NOTIFICATIONS) ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'smart_money_high_importance_channel', 
  'Smart Money Notifications', 
  description: 'This channel is used for important notifications.', 
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Hàm hiển thị thông báo cục bộ dùng chung
void _showLocalNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  String? title = notification?.title ?? message.data['title'];
  String? body = notification?.body ?? message.data['body'];

  if (title != null || body != null) {
    flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/launcher_icon',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          visibility: NotificationVisibility.public, // Hiển thị trên màn hình khóa
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: '/notifications', // Gửi route để điều hướng khi bấm vào
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Hiển thị thông báo khi app đang ở chế độ Background/Terminated
  _showLocalNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
      
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  // Khởi tạo và xử lý khi người dùng BẤM vào thông báo (lúc app đang mở hoặc chạy ngầm)
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        AppRouter.router.push(response.payload!);
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await initializeDateFormatting('vi_VN', null);
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
        ChangeNotifierProvider(create: (_) => BillTransactionProvider()),
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

  void _setupFCM() async {
    // 1. Khi đang mở app (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);

      final notifyIdStr = message.data['id'];
      if (notifyIdStr != null && mounted) {
        try {
          int notifyId = int.parse(notifyIdStr);
          context.read<NotificationProvider>().markAsDelivered(notifyId);
        } catch (e) {
          debugPrint("Lỗi parse notifyId: $e");
        }
      }
    });

    // 2. Khi app đang ở Background và người dùng BẤM vào thông báo của Firebase
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppRouter.router.push('/notifications');
    });

    // 3. Khi app đã bị TẮT hẳn (Terminated) và người dùng mở app từ thông báo
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Đợi một chút để app khởi tạo router xong
      Future.delayed(const Duration(milliseconds: 500), () {
        AppRouter.router.push('/notifications');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      routerDelegate: AppRouter.router.routerDelegate,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routeInformationProvider: AppRouter.router.routeInformationProvider,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    );
  }
}
