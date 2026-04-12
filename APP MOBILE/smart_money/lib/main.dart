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
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

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
    // Thực hiện xin quyền ngay khi khởi tạo app
    _requestNotificationPermissions();
    _setupFCM();
  }

  // Hàm chuyên biệt để xin quyền thông báo trên mọi nền tảng
  Future<void> _requestNotificationPermissions() async {
    // 1. Xin quyền từ Firebase Messaging (iOS + Android 13+)
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('Firebase Permission: ${settings.authorizationStatus}');

    // 2. Xin quyền cụ thể cho Android 13+ để hiển thị Local Notifications (HUD)
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    // Yêu cầu quyền POST_NOTIFICATIONS trên Android 13 trở lên
    final bool? grantedAndroid = await androidImplementation?.requestNotificationsPermission();
    debugPrint('Android Local Notification Permission: $grantedAndroid');
    
    // 3. Xin quyền cụ thể cho iOS (Local Notifications)
    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    
    final bool? grantedIOS = await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('iOS Local Notification Permission: $grantedIOS');
  }

  void _setupFCM() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }

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
