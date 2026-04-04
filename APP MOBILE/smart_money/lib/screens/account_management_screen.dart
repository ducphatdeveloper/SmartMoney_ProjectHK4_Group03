import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../modules/auth/providers/auth_provider.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy instance của AuthProvider
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

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

                // Avatar với chức năng cập nhật
                GestureDetector(
                  onTap: () => _pickAndUploadImage(context, authProvider),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.purple,
                        backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                        child: user?.avatarUrl == null
                            ? Text(
                                (user?.fullname != null && user!.fullname!.isNotEmpty)
                                    ? user.fullname![0].toUpperCase()
                                    : "U", 
                                style: const TextStyle(fontSize: 28, color: Colors.white))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(radius: 10, backgroundColor: Colors.green, child: Icon(Icons.camera_alt, size: 12, color: Colors.white)),
                      )
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
                  user?.fullname ?? "Chưa đặt tên",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),

                const SizedBox(height: 4),

                Text(
                  user?.accEmail ?? "",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== EDIT PROFILE =====
          _button(
            title: "Chỉnh sửa hồ sơ",
            color: Colors.blueAccent,
            onTap: () => context.push('/edit-profile'),
          ),

          const SizedBox(height: 12),

          // ===== CHANGE PASSWORD =====
          _button(
            title: "Thay đổi mật khẩu",
            color: Colors.green,
            onTap: () async {
              final email = user?.accEmail;
              if (email != null) {
                context.push('/reset-password', extra: email);
              }
            },
          ),
          const SizedBox(height: 12),

          // ===== LOGOUT =====
          _button(
            title: "Đăng xuất",
            color: Colors.red,
            onTap: () {
              _confirmLogout(context, authProvider);
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

  Future<void> _pickAndUploadImage(BuildContext context, AuthProvider auth) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Thư viện ảnh', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Chụp ảnh mới', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final XFile? file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newUrl != null ? "Cập nhật ảnh đại diện thành công!" : "Cập nhật thất bại.")),
        );
      }
    }
  }
}
