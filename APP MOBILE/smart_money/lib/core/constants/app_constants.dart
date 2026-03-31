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
    if (Platform.isAndroid) {
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
  // 3. TOKEN KEYS — dùng trong token_helper.dart
  // =============================================

  static const String accessTokenKey  = "access_token";
  static const String refreshTokenKey = "refresh_token";

  // =============================================
  // 4. ENDPOINTS — theo từng module trong blueprint
  // =============================================

  // --- Auth ---
  static String get authLogin         => "$baseUrl/auth/login";
  static String get authRegister      => "$baseUrl/auth/register";
  static String get authLogout        => "$baseUrl/auth/logout";
  static String get authRefreshToken  => "$baseUrl/auth/refresh-token";

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
}
