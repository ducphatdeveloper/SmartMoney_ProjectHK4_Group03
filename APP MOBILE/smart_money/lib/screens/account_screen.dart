import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smart_money/modules/auth/providers/auth_provider.dart';
import 'package:smart_money/modules/category/screens/category_list_screen.dart';
import 'package:smart_money/modules/planned/screens/recurring_screen.dart';
import 'package:smart_money/modules/planned/screens/bill_screen.dart';
import 'package:smart_money/modules/event/screens/event_screen.dart';
import 'package:smart_money/modules/saving_goal/screens/saving_goal_list_screen.dart';
import 'package:smart_money/modules/wallet/screens/wallet_screen.dart';
import 'account_management_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin từ AuthProvider
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Tài khoản"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileCard(auth),
          const SizedBox(height: 24),

          _item(
            Icons.manage_accounts,
            "Quản lý tài khoản",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
              );
            },
          ),

          _item(
            Icons.account_balance_wallet,
            "Ví của tôi",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletListView()),
              );
            },
          ),

          _item(
            Icons.account_balance_wallet,
            "Ví tiết kiệm của tôi",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavingGoalListScreen()),
              );
            },
          ),
          
          _item(Icons.group, "Nhóm" ,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryListScreen()),
                );
              }
          ),

          _item(
            Icons.event,
            "Sự kiện",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventScreen()),
              );
            },
          ),
          _item(
            Icons.autorenew,
            "Giao dịch định kỳ",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringScreen()),
              );
            },
          ),
          _item(
            Icons.receipt_long,
            "Hóa đơn",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillScreen()),
              );
            },
          ),
          _item(Icons.request_page, "Sổ nợ"),

          const SizedBox(height: 16),
          _section("Khác"),
          _item(Icons.build, "Công cụ"),
          _item(Icons.upload_file, "Xuất dữ liệu tới Google Trang tính"),
          _item(Icons.settings, "Cài đặt"),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _profileCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green.shade800,
            child: _buildAvatarContent(auth),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.currentUser?.accUsername ?? "Người dùng SmartMoney",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  auth.userEmail ?? "Thành viên",
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
          width: 60, // Kích thước của CircleAvatar radius * 2
          height: 60,
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
        width: 60,
        height: 60,
        errorBuilder: (_, __, ___) => _textAvatar(username), // Fallback nếu ảnh lỗi
      ),
    );
  }

  // Hàm helper để tạo widget Text cho avatar
  Widget _textAvatar(String username) {
    return Text(
      username.substring(0, 1).toUpperCase(),
      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }

  Widget _item(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}
