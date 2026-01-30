import 'package:flutter/foundation.dart'; // Để dùng kIsWeb
import 'dart:io'; // Để dùng Platform (chỉ chạy trên Mobile/Desktop)

class ApiConstants {
  static String get baseUrl {
    // 1. Ưu tiên check Web trước (vì Platform.isAndroid sẽ lỗi trên Web)
    if (kIsWeb) {
      return "http://localhost:9999/api";
    }

    // 2. Check Android Emulator
    else if (Platform.isAndroid) {
      return "http://10.0.2.2:9999/api";
    }

    // 3. Các trường hợp còn lại (iOS, Windows, macOS)
    else {
      return "http://localhost:9999/api";
    }
  }

  static String get categories => "$baseUrl/categories";
}