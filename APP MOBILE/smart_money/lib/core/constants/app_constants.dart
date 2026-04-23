import 'package:flutter/foundation.dart';
import 'dart:io';

// Hằng số toàn app: baseUrl, token keys, endpoints tất cả module.
// Các Service trong module chỉ cần gọi AppConstants.xxxBase để lấy URL.
class AppConstants {

  // =============================================
  // 1. CẤU HÌNH MÔI TRƯỜNG
  // =============================================

  // Set khi build: flutter run --dart-define=ENVIRONMENT=production
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Set khi test thiết bị thật: flutter run --dart-define=DEV_IP=192.168.1.100
  static const String _devIp = String.fromEnvironment(
    'DEV_IP',
    defaultValue: '',
  );

  // =============================================
  // 2. BASE URL — tự chọn đúng môi trường
  // =============================================

  static String get baseUrl {
    String url;
    if (_environment == 'production') {
      // TODO: Thay bằng domain thật khi deploy lên server
      url = "https://api.your-domain.com/api";
    } else {
      url = _developmentBaseUrl;
    }
    // In log giúp team biết đang kết nối tới server nào
    print("📍 API Base URL: $url (ENV: $_environment)");
    return url;
  }

  static String get _developmentBaseUrl {
    // Ưu tiên IP truyền vào — dùng khi test trên thiết bị thật
    if (_devIp.isNotEmpty) return 'http://$_devIp:9999/api';
    // Web browser
    if (kIsWeb) return "http://localhost:9999/api";
    // Chỉ kiểm tra Platform nếu KHÔNG phải môi trường Web
    if (!kIsWeb && Platform.isAndroid) {
      // CHỖ NÀY QUAN TRỌNG:
      // 10.0.2.2 là dành cho máy ảo.
      // 192.168.x.x (IP máy tính) là dành cho máy thật.

      // Gán ip máy tính thật để test
      String computerIp = "192.168.1.168"; // <--- THAY BẰNG IP MÁY TÍNH (Gõ ipconfig để lấy)

      return "http://$computerIp:9999/api";
    }
    // Máy ảo iOS & Desktop
    return "http://localhost:9999/api";
  }

  // =============================================
  // 3. STORAGE KEYS — dùng trong token_helper.dart
  // =============================================

  static const String accessTokenKey  = "access_token";
  static const String refreshTokenKey = "refresh_token";
  
  // Biometric keys
  static const String biometricEnabledKey = "biometric_enabled";
  static const String biometricUserEmailKey = "biometric_user_email"; // Để biết user nào đang enable biometric

  // =============================================
  // 4. ENDPOINTS — theo từng module trong blueprint
  // =============================================

  // --- Auth ---
  static String get authLogin         => "$baseUrl/auth/login";
  static String get authGoogleLogin   => "$baseUrl/auth/google-login";
  static String get authRegister      => "$baseUrl/auth/register";
  static String get authLogout        => "$baseUrl/auth/logout";
  static String get authForgotPassword => "$baseUrl/auth/forgot-password";
  static String get authResetPassword => "$baseUrl/auth/reset-password";
  static String get authRefreshToken  => "$baseUrl/auth/refresh-token";

  // --- User ---
  static String get userProfile       => "$baseUrl/users/profile";
  static String get userAvatar        => "$baseUrl/users/avatar";
  static String get userSendLockOtp   => "$baseUrl/users/emergency-lock/send-otp";
  static String get userVerifyAndLock => "$baseUrl/users/emergency-lock/verify-and-lock";

  // --- Wallet ---
  static String get walletsBase           => "$baseUrl/user/wallets";
  static String walletById(int id)        => "$baseUrl/user/wallets/$id";

  // --- Transaction ---
  static String get transactionsBase      => "$baseUrl/transactions";

  // --- Category ---
  static String get categoriesBase        => "$baseUrl/categories";

  // --- Budget ---
  static String get budgetsBase           => "$baseUrl/budgets";

  // --- Saving Goal ---
  static String get savingGoalsBase       => "$baseUrl/saving-goals";

  // --- Debt ---
  static String get debtsBase             => "$baseUrl/debts";

  // --- Event ---
  static String get eventsBase            => "$baseUrl/events";

  // --- Utils (date-ranges cho thanh trượt màn hình transaction) ---
  static String get utilDateRanges        => "$baseUrl/utils/date-ranges";

  // --- Icons (lấy danh sách icon từ Cloudinary) ---
  static String get iconsBase             => "$baseUrl/icons";

  // --- Recurring (Giao dịch định kỳ) — planType = 2 ---
  static String get recurringBase         => "$baseUrl/recurring";
  static String recurringById(int id)     => "$baseUrl/recurring/$id";
  static String recurringToggle(int id)   => "$baseUrl/recurring/$id/toggle";

  // --- Bills (Hóa đơn) — planType = 1 ---
  static String get billsBase             => "$baseUrl/bills";
  static String billById(int id)          => "$baseUrl/bills/$id";
  static String billToggle(int id)        => "$baseUrl/bills/$id/toggle";
  static String billPay(int id)           => "$baseUrl/bills/$id/pay";
  static String billTransactions(int id)  => "$baseUrl/bills/$id/transactions"; // Endpoint mới
  // --- Notification ---
  static String get notificationsBase        => "$baseUrl/notifications";
  static String get notificationsUnreadCount => "$baseUrl/notifications/unread-count";
  static String markNotificationRead(int id)  => "$baseUrl/notifications/$id/read";
  static String get markAllNotificationsRead => "$baseUrl/notifications/read-all";
  
  // Mới: Đồng bộ với backend Spring Boot vừa update
  static String get adminSystemNotifications  => "$baseUrl/notifications/admin/system";
  static String markNotificationDelivered(int id) => "$baseUrl/notifications/$id/delivered";
  static String notificationById(int id)      => "$baseUrl/notifications/$id";

  // --- Contact Request ---
  static String get contactRequestsBase => "$baseUrl/contact-requests";
  static String get myContactRequests   => "$baseUrl/contact-requests/my";

  // --- AI Chat & OCR ---
  static String get aiBase              => "$baseUrl/ai";
  static String get aiChat             => "$baseUrl/ai/chat";
  static String get aiUploadReceipt    => "$baseUrl/ai/upload-receipt";
  static String get aiHistory          => "$baseUrl/ai/history";
  static String get aiExecute          => "$baseUrl/ai/execute";
  static String aiDeleteConversation(int id) => "$baseUrl/ai/history/$id";
}
