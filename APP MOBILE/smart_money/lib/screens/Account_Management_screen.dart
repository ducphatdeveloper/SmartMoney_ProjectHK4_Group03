import 'package:flutter/material.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

                // Avatar
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.purple,
                  child: Text(
                    "T",
                    style: TextStyle(fontSize: 28, color: Colors.white),
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

                const Text(
                  "tranminhnhat231205",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),

                const SizedBox(height: 4),

                const Text(
                  "tranminhnhat231205@gmail.com",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== CHANGE PASSWORD =====
          _button(
            title: "Thay đổi mật khẩu",
            color: Colors.green,
            onTap: () {},
          ),

          const SizedBox(height: 20),

          // ===== LOGOUT =====
          _button(
            title: "Đăng xuất",
            color: Colors.red,
            onTap: () {
              _confirmLogout(context);
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
  void _confirmLogout(BuildContext context) {
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
            child: const Text("Đăng xuất"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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
}
