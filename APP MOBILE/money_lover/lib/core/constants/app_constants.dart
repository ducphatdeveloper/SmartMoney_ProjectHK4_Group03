import 'package:flutter/foundation.dart'; // Để check môi trường Web (kIsWeb).
import 'dart:io';                    // Để check nền tảng Native (Android, iOS).

// Quản lý các hằng số API, tự động chọn đúng địa chỉ server theo môi trường.
class AppConstants {
  // Biến môi trường, set khi build app bằng --dart-define.
  // - 'development': (Mặc định) Dùng cho team dev, trỏ tới server local.
  // - 'production': Dùng khi build app cho người dùng, trỏ tới server thật.
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Lấy IP của máy dev, dùng khi test trên thiết bị thật.
  // Ví dụ: flutter run --dart-define=DEV_IP=192.168.1.100
  static const String _devIp = String.fromEnvironment('DEV_IP');

  // Lấy địa chỉ gốc (baseUrl) của API server.
  static String get baseUrl {
    String currentBaseUrl;
    if (_environment == 'production') {
      // MÔI TRƯỜNG PRODUCTION:
      // TODO: Thay thế bằng địa chỉ server công khai của bạn.
      currentBaseUrl = "https://api.your-domain.com/api"; // Thay thế bằng domain thật
    } else {
      // MÔI TRƯỜNG DEVELOPMENT:
      currentBaseUrl = _developmentBaseUrl;
    }
    print("📍 API Base URL đang sử dụng: $currentBaseUrl (Environment: $_environment)");
    return currentBaseUrl;
  }

  // Cung cấp URL cho môi trường development trên các nền tảng khác nhau.
  static String get _developmentBaseUrl {
    // Ưu tiên IP được truyền vào để test trên thiết bị thật.
    if (_devIp.isNotEmpty) {
      return 'http://$_devIp:9999/api';
    }

    // Nếu không có IP, dùng cấu hình cho máy ảo và web.
    if (kIsWeb) {
      // Web: Kết nối tới localhost của máy tính.
      return "http://localhost:9999/api";
    }

    if (Platform.isAndroid) {
      // Máy ảo Android: Dùng IP 10.0.2.2 để trỏ về localhost của máy.
      return "http://10.0.2.2:9999/api";
    }

    // Máy ảo iOS & Desktop: Có thể dùng trực tiếp localhost.
    return "http://localhost:9999/api";
  }

  // --- ENDPOINTS CỤ THỂ CHO CÁC MODULE ---
  // Các service con trong module sẽ tự ghép nối path con vào baseUrl này.

  // Auth Module
  static String get authLogin => "$baseUrl/auth/login";
  static String get authRegister => "$baseUrl/auth/register";

  // Category Module
  static String get categoriesBase => "$baseUrl/categories"; // Base URL cho Category
  // Ví dụ: GET /categories, POST /categories, PUT /categories/{id}, DELETE /categories/{id}

  // Wallet Module
  static String get walletsBase => "$baseUrl/wallets";

  // Transaction Module
  static String get transactionsBase => "$baseUrl/transactions";

  // ... Thêm các base URL khác cho các module khác tại đây
}
