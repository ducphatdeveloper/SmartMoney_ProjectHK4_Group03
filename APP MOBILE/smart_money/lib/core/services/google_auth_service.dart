import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  // Cấu hình GoogleSignIn với thông tin chi tiết hơn
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  Future<GoogleSignInAuthentication?> signInWithGoogle() async {
    try {
      // Đảm bảo đã đăng xuất trước đó để tránh lỗi cache session
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // 1. Khởi động luồng đăng nhập
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("❌ [GoogleAuth] Người dùng đã đóng bảng chọn tài khoản.");
        return null;
      }

      // 2. Lấy authentication (idToken, accessToken)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        debugPrint("❌ [GoogleAuth] Đăng nhập thành công nhưng ID Token bị rỗng.");
        return null;
      }

      debugPrint("🚀 [GoogleAuth] Lấy ID Token thành công.");
      return googleAuth;
    } catch (e) {
      debugPrint("❌ [GoogleAuth] Lỗi hệ thống: $e");
      // Nếu gặp lỗi 12500 hoặc 10, thường là do SHA-1 chưa được thêm vào Firebase
      return null;
    }
  }

  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("Sign out error: $e");
    }
  }
}
