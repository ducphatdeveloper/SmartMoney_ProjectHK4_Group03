import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../modules/auth/providers/auth_provider.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  Future<void> _pickAndUploadImage(BuildContext context, AuthProvider auth) async {
    final ImagePicker picker = ImagePicker();
    
    // Hiển thị lựa chọn Chụp ảnh hoặc Chọn từ thư viện
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Thư viện ảnh', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final XFile? file = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70, // Nén ảnh để tải lên nhanh hơn
                  );
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Chụp ảnh mới', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final XFile? file = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 70,
                  );
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
            ],
          ),
        );
      },
    );

    if (image != null) {
      final String? newUrl = await auth.updateAvatar(image.path);
      
      if (context.mounted) {
        if (newUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cập nhật ảnh đại diện thành công!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cập nhật ảnh đại diện thất bại. Vui lòng thử lại.")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy instance của AuthProvider
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Quản Lý Tài Khoản"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ===== PROFILE CARD =====
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [

                // Professional Avatar with Edit Badge
                GestureDetector(
                  onTap: auth.isLoading ? null : () => _pickAndUploadImage(context, auth),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green.withOpacity(0.5), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.green.shade800, // Màu nền mặc định
                          child: auth.isLoading 
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : _buildAvatarContent(auth), 
                        ),
                      ),
                      // Camera Edit Badge
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1C1C1E), width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "TÀI KHOẢN MIỄN PHÍ",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  auth.currentUser?.accUsername ?? "Người dùng SmartMoney",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),

                const SizedBox(height: 4),

                Text(
                  auth.userEmail ?? "Chưa cập nhật email",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== CHANGE PASSWORD =====
          _button(
            title: "Thay đổi mật khẩu",
            color: auth.isLoading ? Colors.grey : Colors.green,
            onTap: () async {
              final email = auth.userEmail;
              
              if (email == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Không tìm thấy email của bạn. Vui lòng đăng nhập lại.")),
                );
                return;
              }

              if (auth.isLoading) return; // Tránh bấm nhiều lần

              // Gửi OTP
              final success = await auth.requestPasswordReset(email);
              
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Mã OTP đã được gửi tới: $email")),
                  );
                  // Chuyển sang màn hình reset mật khẩu
                  context.push('/reset-password', extra: email);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Không thể gửi mã OTP. Vui lòng kiểm tra lại kết nối.")),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 20),

          // ===== LOGOUT =====
          _button(
            title: "Đăng xuất",
            color: Colors.red,
            onTap: () {
              _confirmLogout(context, auth);
            },
          ),

          const SizedBox(height: 12),

          // ===== DELETE ACCOUNT =====
          _button(
            title: "Xóa tài khoản",
            color: Colors.red,
            onTap: () {
              _confirmDelete(context);
            },
          ),
        ],
      ),
    );
  }

  // ===== BUTTON STYLE =====
  Widget _button({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ===== DIALOG =====
  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc muốn đăng xuất không?"),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              // Đóng dialog xác nhận
              Navigator.pop(context);
              
              // Gọi hàm logout trong AuthProvider
              await authProvider.logout();
              
              // Điều hướng về trang login
              if (context.mounted) {
                context.go("/login");
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xóa tài khoản"),
        content: const Text("Hành động này không thể hoàn tác!"),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // Hàm helper để xây dựng nội dung avatar (xử lý SVG, ảnh thường, hoặc chữ cái đầu)
  Widget? _buildAvatarContent(AuthProvider auth) {
    final url = auth.currentUser?.avatarUrl;
    final username = auth.currentUser?.accUsername ?? "U";

    // 1. Nếu không có URL hoặc URL rỗng, hiển thị chữ cái đầu của username
    if (url == null || url.isEmpty) {
      return _textAvatar(username);
    }

    // 2. Nếu URL là ảnh SVG, sử dụng SvgPicture.network
    if (url.toLowerCase().contains('svg')) {
      return ClipOval(
        child: SvgPicture.network(
          url,
          fit: BoxFit.cover,
          width: 80, // Kích thước của CircleAvatar radius * 2
          height: 80,
          placeholderBuilder: (context) => const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    // 3. Nếu URL là ảnh raster (PNG, JPG, WebP), sử dụng Image.network
    return ClipOval(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (_, __, ___) => _textAvatar(username), // Fallback nếu ảnh lỗi
      ),
    );
  }

  // Hàm helper để tạo widget Text cho avatar
  Widget _textAvatar(String username) {
    return Text(
      username.substring(0, 1).toUpperCase(),
      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}
